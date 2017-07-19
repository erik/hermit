defmodule Hermit do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(Task.Supervisor, [[name: Hermit.TaskSupervisor]]),
      Plug.Adapters.Cowboy.child_spec(:http, Hermit.Web, [], [port: 8090]),
      worker(Hermit.Plumber, []),
      worker(Task, [Hermit.Sink, :listen, [1337]])
    ]

    opts = [strategy: :one_for_one, name: Hermit.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
