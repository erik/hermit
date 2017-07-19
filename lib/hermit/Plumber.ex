# It handles all the pipes.

defmodule Hermit.Plumber do
  require Logger

  def start_link do
    Task.async(&Hermit.Plumber.reap_loop/0)
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

  # Clean up the dead procs every 60 seconds
  def reap_loop do
    Process.sleep(60_000)
    Logger.info "reap."
    Agent.update(__MODULE__, fn state ->
      Map.update(state, :pipe_listeners, %{}, fn dict ->
        dict
        |> Enum.map(fn {id, pids} -> {id, Enum.filter(pids, &Process.alive?/1)} end)
        |> Enum.into(%{})
      end)
    end)

    reap_loop()
  end

  defp initial_state do
    %{
      :pipe_listeners => %{},
      :last_id => 0
    }
  end
end
