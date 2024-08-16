defmodule Macfly.MixProject do
  use Mix.Project

  @source_url "https://github.com/superfly/macaroon-elixir"
  @version "0.2.15"

  def project do
    [
      app: :macfly,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      consolidate_protocols: Mix.env() != :test,
      elixirc_paths: if(Mix.env() == :test, do: [:lib, :test], else: [:lib]),
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:msgpax, "~> 2.3"},
      {:httpoison, "~> 1.8"},
      {:json, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      name: "macfly",
      description: "library for working with fly.io macaroon tokens",
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
