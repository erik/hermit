defmodule Hermit.Mixfile do
  use Mix.Project

  def project do
    [app: :hermit,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  def application do
    [applications: [:cowboy, :plug],
     extra_applications: [:logger],
     mod: {Hermit, []}]
  end

  defp deps do
    [{:cowboy, "~> 1.0.0"},
     {:plug, "~> 1.0"}]
  end
end
