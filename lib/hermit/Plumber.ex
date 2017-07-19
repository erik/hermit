# It handles all the pipes.

defmodule Hermit.Plumber do
  require Logger

  defstruct pipes: %{}, last_id: 0

  defmodule Pipe do
    defstruct id: 0, active: true, listeners: MapSet.new()
  end

  def start_link do
    Task.async(&Hermit.Plumber.reap_loop/0)
    Agent.start_link(fn -> %Hermit.Plumber{} end, name: __MODULE__)
  end

  # Create a new pipe and return the id
  def new_pipe do
    Agent.get_and_update(__MODULE__, fn state ->
      id = state.last_id + 1 |> to_string
      next_state = %{
        state |
        last_id: state.last_id + 1,
        pipes: state.pipes |> Map.put(id, %Pipe{id: id})
      }

      { id, next_state }
    end)
  end

  def add_pipe_listener(pipe_id, pid) do
    Agent.update(__MODULE__, fn state ->
      x = %{ state |
         pipes: Map.update(state.pipes, pipe_id, %Pipe{listeners: MapSet.new([pid])},
           fn pipe ->
             %{pipe | listeners: MapSet.put(pipe.listeners, pid)}
           end)
           }

      IO.puts "new state #{inspect x}"
      x
    end)
  end

  # Send a message to all PIDs listening to this pipe
  defp broadcast_pipe_listeners(pipe_id, msg) do
    Agent.get(__MODULE__, fn state ->
      state.pipes
      |> Map.get(pipe_id, %Pipe{})
      |> Map.get(:listeners)
    end)
    |> Enum.each(fn pid ->
      IO.puts "sending to #{inspect pid}"
      send(pid, msg)
    end)
  end

  def pipe_input(pipe_id, content) do
    broadcast_pipe_listeners(pipe_id, { :pipe_activity, content })
  end

  def close_pipe(pipe_id) do
    Agent.update(__MODULE__, fn state ->
      %{ state |
         pipes: state.pipes
         |> Map.put(pipe_id, %{state.pipes[pipe_id] | active: false})
      }
    end)

    broadcast_pipe_listeners(pipe_id, { :closed })
  end

  # Clean up the dead procs every 60 seconds
  def reap_loop do
    Process.sleep(60_000)
    Logger.info "reap."
    Agent.update(__MODULE__, fn state ->
      %{ state |
         pipes: state.pipes
         |> Enum.map(fn {id, pipe} ->
           {id, %{ pipe | listeners: Enum.filter(pipe.listeners, &Process.alive?/1)}}
         end)
         |> Enum.into(%{})
      }
    end)

    reap_loop()
  end
end
