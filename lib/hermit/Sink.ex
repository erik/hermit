defmodule Hermit.Sink do
  require Logger

  def listen(port) do
    {:ok, socket} = :gen_tcp.listen(port,
      [:binary, active: false, reuseaddr: true])
    Logger.info "Accepting connections on port #{port}"

    listen_loop(socket)
  end

  defp listen_loop(socket) do
    base_url = Application.get_env(:hermit, :base_url)
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} = Task.Supervisor.start_child(Hermit.TaskSupervisor, fn ->
      pipe_id = Hermit.Plumber.new_pipe()
      :gen_tcp.send(client, "Your pipe is available at #{base_url}/v/#{pipe_id}\n")
      serve(client, pipe_id)
    end)

    :ok = :gen_tcp.controlling_process(client, pid)

    listen_loop(socket)
  end

  defp serve(socket, pipe_id) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, chunk} ->
        Hermit.Plumber.pipe_input(pipe_id, chunk)
        serve(socket, pipe_id)

      {:error, :closed} ->
        Logger.info("Client finished")
        Hermit.Plumber.close_pipe(pipe_id)
    end
  end
end
