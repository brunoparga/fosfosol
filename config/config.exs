defmodule Fosfosol.Config do
  import Config

  config :elixir_google_spreadsheets, json: "./config/api_key.json" |> File.read!()

  config :elixir_google_spreadsheets, :client,
    request_workers: 5,
    max_demand: 100,
    max_interval: :timer.minutes(1),
    interval: 100,
    result_timeout: :timer.minutes(10)
end
