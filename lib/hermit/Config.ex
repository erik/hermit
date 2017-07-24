defmodule Hermit.Config do

  def sink_port do
    get_env("HERMIT_SINK_PORT", "1337")
    |> String.to_integer
  end

  def sink_bind do
    get_env("HERMIT_BIND", "0.0.0.0")
  end

  def web_port do
    get_env("HERMIT_WEB_PORT", "8090")
    |> String.to_integer
  end

  def host do
    get_env("HERMIT_HOST", "localhost")
  end

  def log_dir do
    get_env("HERMIT_DIR", "/tmp/hermit")
  end

  def base_url do
    get_env("HERMIT_URL", "http://#{host()}:#{web_port()}")
  end

  def max_file do
    # lol, this is bad.
    { byte_size, _} = get_env("HERMIT_MAX_SIZE", "999 T")
    |> String.downcase
    |> String.replace("t", " * 1024 g")
    |> String.replace("g", " * 1024 m")
    |> String.replace("m", " * 1024 k")
    |> String.replace("k", " * 1024")
    |> Code.eval_string

    byte_size
  end

  defp get_env(key, default) do
    System.get_env(key) || default
  end

end
