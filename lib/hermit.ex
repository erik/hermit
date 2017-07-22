defmodule Hermit do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    web_port = Application.get_env(:hermit, :web_port)
    sink_port = Application.get_env(:hermit, :sink_port)

    children = [
      supervisor(Task.Supervisor, [[name: Hermit.TaskSupervisor]]),
      Plug.Adapters.Cowboy.child_spec(:http, Hermit.Web, [], [port: web_port]),
      worker(Hermit.Plumber, []),
      worker(Task, [Hermit.Sink, :listen, [sink_port]])
    ]

    opts = [strategy: :one_for_one, name: Hermit.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
