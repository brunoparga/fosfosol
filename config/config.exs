defmodule Fosfosol.Config do
  import Config

  file = if System.get_env("PROD") == "true", do: "prod", else: "test"

  config :fosfosol,
         "./config/#{file}_settings.json"
         |> File.read!()
         |> Jason.decode!(keys: :atoms, objects: :ordered_objects)
         |> Keyword.new()
         |> Keyword.update!(:environment, &String.to_atom/1)

  config :elixir_google_spreadsheets, json: "./config/api_key.json" |> File.read!()

  config :elixir_google_spreadsheets, :client,
    request_workers: 50,
    max_demand: 100,
    max_interval: :timer.minutes(1),
    interval: 100,
    result_timeout: :timer.minutes(10)

  config :logger,
    backends: [:console],
    compile_time_purge_matching: [
      [application: :elixir_google_spreadsheets]
    ]
end
