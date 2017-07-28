defmodule Hermit.Config do
  # HERMIT_SINK_PORT
  #
  # TCP port for hermit to listen to incoming pipe connections
  def sink_port do
    get_env("HERMIT_SINK_PORT", "1337")
    |> String.to_integer
  end

  # HERMIT_BIND
  #
  # Address for hermit to bind to. For example, binding to 127.0.0.1
  # will cause hermit to reject all traffic from outside the local
  # machine, while binding to 0.0.0.0 will allow traffic from
  # anywhere.
  def sink_bind do
    get_env("HERMIT_BIND", "0.0.0.0")
  end

  # HERMIT_WEB_PORT
  #
  # Port for hermit to start its web server on.
  def web_port do
    get_env("HERMIT_WEB_PORT", "8090")
    |> String.to_integer
  end

  # HERMIT_HOST
  #
  # Hostname of the hermit server. Used to report to clients where
  # they can view their pipes
  def host do
    get_env("HERMIT_HOST", "localhost")
  end

  # HERMIT_DIR
  #
  # Directory to store logs in
  def log_dir do
    get_env("HERMIT_DIR", "/tmp/hermit")
  end

  # HERMIT_URL
  #
  # Base URL from which the hermit server is accessible from the
  # outside world. Default is sane unless hermit is running behind
  # nginx or another similar reverse proxy.
  def base_url do
    get_env("HERMIT_URL", "http://#{host()}:#{web_port()}")
  end

  # HERMIT_MAX_SIZE
  #
  # Maximum size of each pipe. Defaults to effectively unlimited
  # (999TB), Use T, G, M, K suffixes to avoid doing math.
  def max_file do
    # lol, this is bad.
    {byte_size, _} = get_env("HERMIT_MAX_SIZE", "999 T")
    |> String.downcase
    |> String.replace("t", " * 1024 g")
    |> String.replace("g", " * 1024 m")
    |> String.replace("m", " * 1024 k")
    |> String.replace("k", " * 1024")
    |> Code.eval_string

    byte_size
  end

  # HERMIT_PIPE_EXPIRATION
  #
  # If set, inactive pipe log files will be deleted after specified
  # duration. If left unset, log files will never expire and must be
  # rotated by some other process.
  #
  # Duration is in seconds, using "d" (day), "h" (hour), "m" (minute)
  # as suffixes for convenience (e.g. "3600" == "60m" == "1h")
  def pipe_expiration do
    if duration = System.get_env("HERMIT_PIPE_EXPIRATION") do
      {duration, _} =
        duration
        |> String.downcase
        |> String.replace("d", "* 24 h")
        |> String.replace("h", "* 60 m")
        |> String.replace("m", "* 60")
        |> Code.eval_string

      duration * 1000
    end
  end

  # HERMIT_SHOW_LISTING
  #
  # When set to "true", expose the /pipes web endpoint to display a
  # list of active and inactive pipes this server has seen. If this
  # hermit isn't exposed to the internet, it's probably what you'd
  # want. Set to "false" or leave unset to disable.
  def show_listing do
    case get_env("HERMIT_SHOW_LISTING", "false") do
      "true" -> true
      "false" -> false
      _ -> raise ArgumentError, message: "invalid HERMIT_SHOW_LISTING \
value, expected true/false"
    end
  end

  defp get_env(key, default) do
    System.get_env(key) || default
  end

end
