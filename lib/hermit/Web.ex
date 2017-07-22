defmodule Hermit.Web do
  use Plug.Router


  plug :match
  plug :dispatch

  # TODO: might as well template in the environment variables.
  get "/" do
    send_file(conn, 200, "./web/index.html")
  end

  # Plain text
  get "/p/:pipe_id" do
    Hermit.Plumber.add_pipe_listener(pipe_id, self())

    conn
    |> put_resp_header("content-type", "text/plain")
    |> send_chunked(200)
    |> send_replay(pipe_id, :plain)
    |> listen_loop(:plain)
  end

  get "/v/:pipe_id" do
    send_file(conn, 200, "./web/pipe_view.html")
  end

  get "/sse/:pipe_id" do
    # Register our process as a pipe listener
    Hermit.Plumber.add_pipe_listener(pipe_id, self())

    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> send_chunked(200)
    |> send_replay(pipe_id, :sse)
    |> listen_loop(:sse)
  end

  defp send_replay(conn, pipe_id, format) do
    # FIXME: this feels like a really bad separation of concerns
    Agent.get(Hermit.Plumber, fn _state ->
      pipe_id
      |> Hermit.Plumber.get_pipe_file
      |> File.stream!([], 2048)
      |> Enum.map(&(format_chunk(&1, format)))
      |> Enum.into(conn)
    end)
  end

  defp format_chunk(bytes, format) do
    case format do
      :sse ->
        encoded = Base.encode64(bytes)
        "data: #{encoded}\n\n"
      :plain ->
        bytes
    end
  end

  defp write_chunk(conn, msg) do
    {:ok, conn} = chunk(conn, msg)
    conn
  end

  defp listen_loop(conn, format) do
    receive do
      { :pipe_activity, msg } ->
        conn
        |> write_chunk(msg |> format_chunk(format))
        |> listen_loop(format)

      { :closed } ->
        conn
    end
  end

  match _ do
    send_resp(conn, 404, "fo oh fo")
  end
end
