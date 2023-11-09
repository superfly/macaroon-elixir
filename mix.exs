defmodule Macfly.MixProject do
  use Mix.Project

  def project do
    [
      app: :macfly,
      version: "0.2.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      consolidate_protocols: Mix.env() != :test,
      elixirc_paths: if(Mix.env() == :test, do: [:lib, :test], else: [:lib]),
      package: package()
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
      {:httpoison, "~> 2.2"},
      {:json, "~> 1.4"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      name: "macfly",
      description: "library for working with fly.io macaroon tokens",
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/superfly/macaroon-elixir"}
    ]
  end
end
