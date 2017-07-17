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
      # initialize(client)
      serve(client)
    end)

    :ok = :gen_tcp.controlling_process(client, pid)

    listen_loop(socket)
  end

  defp serve(socket) do
    socket
    |> read_line()
    |> write_line(socket)

    serve(socket)
  end

  defp read_line(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  defp write_line(line, socket) do
    :gen_tcp.send(socket, line)
  end
end
