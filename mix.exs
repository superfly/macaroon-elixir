defmodule Macfly.MixProject do
  use Mix.Project

  def project do
    [
      app: :macfly,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:msgpax, "~> 2.4.0"},
      {:json, "~> 1.4.1", only: [:test]},
    ]
  end
end
