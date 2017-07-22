# It handles all the pipes.

defmodule Hermit.Plumber do
  require Logger

  defmodule Pipe do
    defstruct id: '', fp: nil, active: false, listeners: []
  end

  @log_dir Application.get_env(:hermit, :log_dir)

  def start_link do
    Task.async(&Hermit.Plumber.reap_loop/0)
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  # Create a new pipe and return the id
  def new_pipe do
    # Generate a random id to use as the file name
    pipe_id = :crypto.strong_rand_bytes(6)
    |> Base.url_encode64

    :ok = Agent.update(__MODULE__, fn state ->
      {:ok, file} =
        pipe_id
        |> get_pipe_file()
        |> File.open([:raw, :write])

      Map.put(state, pipe_id, %Pipe{id: pipe_id, fp: file, active: true})
    end)

    pipe_id
  end

  def add_pipe_listener(pipe_id, pid) do
    Agent.update(__MODULE__, fn state ->
      Map.update(state, pipe_id, %Pipe{id: pipe_id}, fn pipe ->
        # Only add listeners to pipes that are active.
        if pipe.active do
          %{pipe | listeners: [pid | pipe.listeners]}
        else
          send pid, { :closed }
          pipe
        end
      end)
    end)
  end

  # Send a message to all PIDs listening to this pipe
  defp broadcast_pipe_listeners(pipe, msg) do
    pipe
    |> Map.get(:listeners)
    |> Enum.each(&(send &1, msg))
  end

  # FIXME: need a limit on total bytes written.
  def pipe_input(pipe_id, content) do
    Agent.get(__MODULE__, fn state ->
      pipe = Map.get(state, pipe_id, %Pipe{})

      true = pipe.active
      :ok = IO.binwrite(pipe.fp, content)

      pipe
    end)
    |> broadcast_pipe_listeners({ :pipe_activity, content })
  end

  def close_pipe(pipe_id) do
    Agent.get_and_update(__MODULE__, fn state ->
      state_ = Map.update!(state, pipe_id, fn pipe ->
        :ok = File.close(pipe.fp)
        %{ pipe | active: false }
      end)

      { Map.get(state_, pipe_id), state_ }
    end)
    |> broadcast_pipe_listeners({ :closed })
  end

  def get_pipe_file(pipe_id) do
    @log_dir
    |> Path.join(pipe_id)
  end

  # Clean up the dead procs every 60 seconds
  def reap_loop do
    Process.sleep(60_000)

    Agent.update(__MODULE__, fn state ->
      state
      |> Enum.map(fn {id, pipe} ->
        {id, %{ pipe | listeners: Enum.filter(pipe.listeners, &Process.alive?/1)}}
      end)
      |> Enum.into(%{})
    end)

    reap_loop()
  end
end
