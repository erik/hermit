use Mix.Config

sink_port = System.get_env("HERMIT_SINK") || "1337"
web_port = System.get_env("HERMIT_WEB") || "8090"
host = System.get_env("HERMIT_HOST") || "localhost"
log_dir = System.get_env("HERMIT_DIR") || "/tmp/hermit/"
base_url = System.get_env("HERMIT_URL") || "http://#{host}:#{web_port}"

config :hermit,
  sink_port: sink_port |> String.to_integer,
  web_port: web_port |> String.to_integer,
  host: host,
  log_dir: log_dir,
  base_url: base_url
