defmodule Hermit.Web do
  use Plug.Router


  plug :match
  plug :dispatch

  get "/" do
    send_resp(conn, 200, "TODO: some kind of listing thing.")
  end

  get "/v/:pipe_id" do
    send_file(conn, 200, "./web/index.html")
  end

  get "/sse/:pipe_id" do
    # Register our process as a pipe listener
    Hermit.Plumber.add_pipe_listener(pipe_id, self())

    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> send_chunked(200)
    |> send_replay(pipe_id)
    |> listen_loop()
  end

  defp send_replay(conn, pipe_id) do
    # FIXME: this feels like a really bad separation of concerns
    Agent.get(Hermit.Plumber, fn _state ->
      pipe_id
      |> Hermit.Plumber.get_pipe_file
      |> File.stream!([], 2048)
      |> Enum.map(&format_chunk/1)
      |> Enum.into(conn)
    end)
  end

  defp format_chunk(bytes) do
    encoded = Base.encode64(bytes)
    "data: #{encoded}\n\n"
  end

  defp write_chunk(conn, msg) do
    {:ok, conn} = chunk(conn, msg)
    conn
  end

  defp listen_loop(conn) do
    receive do
      {:pipe_activity, msg} ->
        conn
        |> write_chunk(msg |> format_chunk())
        |> listen_loop()
    end
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
