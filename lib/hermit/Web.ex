defmodule Hermit.Web do
  use Plug.Router


  plug :match
  plug :dispatch

  get "/" do
    send_file(conn, 200, "./web/index.html")
  end

  get "/v/:pipe_id" do
    send_resp(conn, 200, "world")
  end

  get "/sse/:pipe_id" do
    # Register our process as a pipe listener
    Hermit.Plumber.add_pipe_listener(pipe_id, self())

    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> send_chunked(200)
    |> listen_loop()
  end

  defp listen_loop(conn) do
    receive do
      {:pipe_activity, msg} ->
        encoded = Base.encode64(msg)
        {:ok, conn} = chunk(conn, "data: #{encoded}\n\n")

        listen_loop(conn)
    end
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
