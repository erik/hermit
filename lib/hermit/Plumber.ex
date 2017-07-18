# It handles all the pipes.

defmodule Hermit.Plumber do

  def start_link do
    # TODO: schedule reap() call.
    Agent.start_link(fn -> initial_state() end, name: __MODULE__)
  end

  def next_pipe_id do
    Agent.get_and_update(__MODULE__, fn state ->
      last = state[:last_id]
      {last + 1, Map.put(state, :last_id, last+1)}
    end)
  end

  def add_pipe_listener(pipe_id, pid) do
    Agent.update(__MODULE__, fn state ->
      Map.update(state, :pipe_listeners, %{}, fn dict ->
        Map.update(dict, pipe_id, MapSet.new(), &(MapSet.put(&1, pid)))
      end)
    end)
  end

  def broadcast_pipe(content, pipe_id) do
    Agent.get(__MODULE__,
      &(Map.get(&1, :pipe_listeners, %{})
      |> Map.get(pipe_id, MapSet.new)))
    |> Enum.each(&Kernel.send(&1, { :pipe_activity, content }))
  end

  # Clean up the zombies.
  # TODO: This should be called in a loop every X seconds
  defp reap do
    Agent.update(__MODULE__, fn state ->
      Map.update(state, :pipe_listeners, %{}, fn dict ->
        dict
        |> Enum.map(fn {id, pids} -> {id, Enum.filter(pids, &Process.alive?/1)} end)
        |> Enum.into(%{})
      end)
    end)
  end

  defp initial_state do
    %{
      :pipe_listeners => %{},
      :last_id => 0
    }
  end
end
