defmodule Hermit do
  require Logger
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    web_port = Hermit.Config.web_port
    sink_port = Hermit.Config.sink_port

    children = [
      supervisor(Task.Supervisor, [[name: Hermit.TaskSupervisor]]),
      Plug.Adapters.Cowboy.child_spec(:http, Hermit.Web, [], [port: web_port]),
      worker(Hermit.Plumber, []),
      worker(Task, [Hermit.Sink, :listen, [sink_port]])
    ]

    Logger.info "Starting hermit web: #{Hermit.Config.base_url}"

    opts = [strategy: :one_for_one, name: Hermit.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
