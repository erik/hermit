# It handles all the pipes.

defmodule Hermit.Plumber do
  use GenServer

  require Logger

  defmodule Pipe do
    defstruct id: '', fp: nil, listeners: [], active: false, bytes_written: 0
  end

  # Client
  def start_link do
    GenServer.start_link(__MODULE__, {nil, Map.new()}, [name: __MODULE__])
  end

  def init({_pipes, refs}) do
    existing_pipes = find_existing_pipes()

    existing_pipes
    |> Map.keys
    |> Enum.each(&schedule_expiration/1)

    {:ok, {existing_pipes, refs}}
  end

  def get_pipe_file(pipe_id) do
    Hermit.Config.log_dir
    |> Path.join(pipe_id)
  end

  # Create a new pipe and return the id
  def new_pipe do
    # Generate a random id to use as the file name
    pipe_id = :crypto.strong_rand_bytes(6)
    |> Base.url_encode64

    GenServer.call(__MODULE__, {:new_pipe, pipe_id})

    pipe_id
  end

  def get_all do
    GenServer.call(__MODULE__, {:get_all})
  end

  def get_pipe(pipe_id) do
    GenServer.call(__MODULE__, {:get_pipe, pipe_id})
  end

  def valid_pipe?(pipe_id) do
    pipe = GenServer.call(__MODULE__, {:get_pipe, pipe_id})
    pipe != nil
  end

  def add_pipe_listener(pipe_id, pid) do
    GenServer.cast(__MODULE__, {:add_pipe_listener, pipe_id, pid})
  end

  # Write content to pipe log file, then fan out to all listening PIDs.
  #
  # FIXME: Maybe want to move the write outside of this function?
  # FIXME: Seems wasteful to only allow one thing to write at a time.
  def pipe_input(pipe_id, content) do
    GenServer.call(__MODULE__, {:pipe_input, pipe_id, content})
  end

  # Mark a pipe as closed so that it can't be written to, and inform all
  # active listeners.
  def close_pipe(pipe_id) do
    GenServer.cast(__MODULE__, {:close_pipe, pipe_id})
  end


  # Server callbacks

  def handle_call({:get_pipe, pipe_id}, _from, {pipes, _refs} = state) do
    {:reply, Map.get(pipes, pipe_id), state}
  end

  def handle_call({:get_all}, _from, {pipes, _refs} = state) do
    {:reply, Map.values(pipes), state}
  end

  def handle_call({:pipe_input, pipe_id, content}, _from, {pipes, refs} = state) do
    pipe = Map.get(pipes, pipe_id)
    size = pipe.bytes_written + byte_size(content)

    cond do
      # This should be impossible...
      not pipe.active ->
        {:reply, :closed, state}

      size >= Hermit.Config.max_file ->
        {:reply, :file_too_large, state}

      :else ->
        :ok = IO.binwrite(pipe.fp, content)

        broadcast_pipe_listeners(pipe, {:pipe_activity, content})

        pipes = Map.put(pipes, pipe_id, %{pipe | bytes_written: size})
        {:reply, :ok, {pipes, refs}}
    end
  end

  def handle_call({:new_pipe, pipe_id}, _from, {pipes, refs}) do
    {:ok, file} = pipe_id
    |> get_pipe_file()
    |> File.open([:raw, :write])

    pipe = %Pipe{id: pipe_id, fp: file, active: true}

    {:reply, :ok, {Map.put(pipes, pipe_id, pipe), refs}}
  end

  def handle_cast({:add_pipe_listener, pipe_id, pid}, {pipes, refs}) do
    pipe = Map.get(pipes, pipe_id)
    if pipe != nil and pipe.active do
        ref = Process.monitor(pid)
        pipe = %{ pipe | listeners: [pid | pipe.listeners] }

        {:noreply, { Map.put(pipes, pipe_id, pipe),
                     Map.put(refs, ref, pipe_id)}}
    else
      send pid, {:closed}
      {:noreply, {pipes, refs}}
    end
  end

  def handle_cast({:close_pipe, pipe_id}, {pipes, refs}) do
    pipe = Map.get(pipes, pipe_id)
    :ok = File.close(pipe.fp)
    schedule_expiration(pipe_id)

    broadcast_pipe_listeners(pipe, {:closed})
    {:noreply, {Map.put(pipes, pipe_id, %{pipe | active: false}), refs}}
  end

  # Pipe listener closed the connection, remove it from existing pipe id
  def handle_info({:DOWN, ref, :process, pid, _reason}, {pipes, refs}) do
    {pipe_id, refs} = Map.pop(refs, ref)
    pipes = Map.update!(pipes, pipe_id, fn pipe ->
      %{ pipe | listeners: List.delete(pipe.listeners, pid)}
    end)

    {:noreply, {pipes, refs}}
  end

  def handle_info({:expire_pipe, pipe_id}, {pipes, refs}) do
    :ok = pipe_id
    |> get_pipe_file()
    |> File.rm()

    {:noreply, {Map.delete(pipes, pipe_id), refs}}
  end

  # Other

  # Get files that were created by previous runs of hermit.
  defp find_existing_pipes() do
    {:ok, files} = File.ls(Hermit.Config.log_dir)

    files
    |> Enum.map(fn pipe_id ->
      {:ok, stat} =
        pipe_id
        |> get_pipe_file
        |> File.stat

      {pipe_id, %Pipe{id: pipe_id, active: false, bytes_written: stat.size}}
    end)
    |> Enum.into(%{})
  end

  # Send a message to all PIDs listening to this pipe.
  defp broadcast_pipe_listeners(pipe, msg) do
    pipe
    |> Map.get(:listeners)
    |> Enum.each(&(send &1, msg))
  end

  defp schedule_expiration(pipe_id) do
    if duration = Hermit.Config.pipe_expiration do
      Process.send_after(self(), {:expire_pipe, pipe_id}, duration)
    end
  end
end
