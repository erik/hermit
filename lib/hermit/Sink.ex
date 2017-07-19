defmodule Hermit.Sink do
  require Logger

  def listen(port) do
    {:ok, socket} = :gen_tcp.listen(port,
      [:binary, packet: :raw, active: false, reuseaddr: true])
    Logger.info "Accepting connections on port #{port}"

    listen_loop(socket)
  end

  defp listen_loop(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} = Task.Supervisor.start_child(Hermit.TaskSupervisor, fn ->
      pipe_id = Hermit.Plumber.next_pipe_id()
      :gen_tcp.send(client, "Your pipe is available at #{pipe_id}\n")
      serve(client, pipe_id)
    end)

    :ok = :gen_tcp.controlling_process(client, pid)

    listen_loop(socket)
  end

  defp serve(socket, pipe_id) do
    {status, chunk} = :gen_tcp.recv(socket, 0)

    if status == :ok do
      Hermit.Plumber.broadcast_pipe(chunk, pipe_id)
      serve(socket, pipe_id)
    else
      Logger.info("Client finished")
    end
  end
end
