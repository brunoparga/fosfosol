defmodule Fosfosol.MixProject do
  use Mix.Project

  @app :fosfosol

  def project do
    [
      aliases: [
        # This could go into an aliases function
        "deps.get": ["deps.get", "gleam.deps.get"]
      ],
      app: :fosfosol,
      archives: [mix_gleam: "~> 0.6"],
      compilers: [:gleam | Mix.compilers()],
      deps: deps(),
      elixir: "~> 1.14",
      erlc_include_path: "build/dev/erlang/#{@app}/include",
      erlc_paths: [
        "build/dev/erlang/#{@app}/_gleam_artefacts",
      ],
      prune_code_paths: false,
      start_permanent: Mix.env() == :prod,
      version: "0.2.0",
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
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:anki_connect, "~> 0.1.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      # TODO: read this dependency from github
      {:elixir_google_spreadsheets, "~> 0.3", path: "../elixir_google_spreadsheets"},
      {:gleam_stdlib, "~> 0.34 or ~> 1.0"},
      {:gleeunit, "~> 1.0", only: [:dev, :test], runtime: false},
      {:jason, "~> 1.4"}
    ]
  end
end
