# It handles all the pipes.

defmodule Hermit.Plumber do

  def start_link do
    {:ok, pid} = Agent.start_link(fn -> initial_state() end, name: __MODULE__)
    reap()

    {:ok, pid}
  end

  def next_pipe_id do
    Agent.get_and_update(__MODULE__, fn state ->
      last = state[:last_id]
      {last + 1, Map.put(state, :last_id, last+1)}
    end)
  end

  def add_pipe_listener(pid) do
    Agent.update(__MODULE__, fn state ->
      # TODO: write me
    end)
  end

  # Clean up the zombies.
  defp reap do
    Agent.update(__MODULE__, fn state ->
      state[:stream_listeners]
      |> Enum.map(fn {id, pids} ->
        {id, Enum.filter(pids, &Process.alive?/1)}
      end)
    end)
  end

  defp initial_state do
    %{
      :stream_listeners => %{},
      :last_id => 0
    }
  end
end
