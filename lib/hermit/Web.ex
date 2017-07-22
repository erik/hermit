defmodule Hermit.Web do
  use Plug.Router
  require EEx


  plug :match
  plug :dispatch

  EEx.function_from_file(:defp, :index_template, "./web/index.html")
  EEx.function_from_file(:defp, :pipe_template, "./web/pipe_view.html", [:sse_url])

  get "/" do
    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, index_template())
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
    base_url = Application.get_env(:hermit, :base_url)
    sse_url = "#{base_url}/stream/#{pipe_id}"

    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, pipe_template(sse_url))
  end

  get "/stream/:pipe_id" do
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
