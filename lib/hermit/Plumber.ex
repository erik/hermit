# It handles all the pipes.

defmodule Hermit.Plumber do
  require Logger

  defmodule Pipe do
    defstruct id: '', fp: nil, active: false, listeners: [], bytes_written: 0
  end

  def start_link do
    Task.async(&Hermit.Plumber.cleanup_listeners/0)
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end


  # Create a new pipe and return the id
  def new_pipe do
    # Generate a random id to use as the file name
    pipe_id = :crypto.strong_rand_bytes(6)
    |> Base.url_encode64

    Agent.update(__MODULE__, fn state ->
      {:ok, file} =
        pipe_id
        |> get_pipe_file()
        |> File.open([:raw, :write])

      Map.put(state, pipe_id, %Pipe{id: pipe_id, fp: file, active: true})
    end)

    pipe_id
  end

  # A pipe_id is valid if it is tracked in the agent state or there is a file
  # with the same name.
  def valid_pipe?(pipe_id) do
    Agent.get(__MODULE__, &(Map.get(&1, pipe_id))) ||
      (pipe_id |> get_pipe_file() |> File.exists?)
  end


  # If specified pipe isn't already closed, add the PID as a
  # listener. Otherwise, immediately respond with a closed message.
  def add_pipe_listener(pipe_id, pid) do
    Agent.update(__MODULE__, fn state ->
      Map.update(state, pipe_id, %Pipe{id: pipe_id}, fn pipe ->
        # Only add listeners to pipes that are active.
        if pipe.active do
          %{pipe | listeners: [pid | pipe.listeners]}
        else
          send pid, {:closed}
          pipe
        end
      end)
    end)
  end


  # Send a message to all PIDs listening to this pipe.
  defp broadcast_pipe_listeners(pipe, msg) do
    pipe
    |> Map.get(:listeners)
    |> Enum.each(&(send &1, msg))
  end


  # Write content to pipe log file, then fan out to all listening PIDs.
  #
  # FIXME: Maybe want to move the write outside of this function?
  # FIXME: Seems wasteful to only allow one thing to write at a time.
  def pipe_input(pipe_id, content) do
    Agent.get_and_update(__MODULE__, fn state ->
      pipe = state |> Map.get(pipe_id)
      size = pipe.bytes_written + byte_size(content)

      cond do
          # This should be impossible...
        not pipe.active ->
          {:closed, state}

        size >= Hermit.Config.max_file ->
          {:file_too_large, state}

        :else ->
          :ok = IO.binwrite(pipe.fp, content)
          broadcast_pipe_listeners(pipe, {:pipe_activity, content})

          {:ok, Map.put(state, pipe_id, %{pipe | bytes_written: size})}
      end
    end)
  end


  # Mark a pipe as closed so that it can't be written to, and inform all
  # active listeners.
  def close_pipe(pipe_id) do
    Agent.update(__MODULE__, fn state ->
      Map.update!(state, pipe_id, fn pipe ->
        :ok = File.close(pipe.fp)
        broadcast_pipe_listeners(pipe, {:closed})
        %{pipe | active: false}
      end)
    end)
  end

  def get_pipe_file(pipe_id) do
    Hermit.Config.log_dir
    |> Path.join(pipe_id)
  end


  # Clean up closed connections.
  #
  # This function does not terminate.
  def cleanup_listeners do
    Process.sleep(60_000)

    Agent.update(__MODULE__, fn state ->
      state
      |> Enum.map(fn {id, pipe} ->
        {id, %{pipe | listeners: Enum.filter(pipe.listeners, &Process.alive?/1)}}
      end)
      |> Enum.into(%{})
    end)

    cleanup_listeners()
  end
end
