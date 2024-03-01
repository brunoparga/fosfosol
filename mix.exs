defmodule Fosfosol.MixProject do
  use Mix.Project

  def project do
    [
      app: :fosfosol,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:elixir_google_spreadsheets, :logger],
      mod: {Fosfosol, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:anki_connect, "~> 0.1.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      # TODO: read this dependency from github
      {:elixir_google_spreadsheets, "~> 0.3", path: "../elixir_google_spreadsheets"},
      {:jason, "~> 1.4"}
    ]
  end
end
