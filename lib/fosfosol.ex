defmodule Fosfosol do
  @moduledoc """
  Documentation for `Fosfosol`.
  """

  use Application

  def start(_type, _args) do
    sync()
    {:ok, self()}
  end

  @doc """
  Run the synchronization between Google Spreadsheets and Anki.
  """
  def sync do
    {:ok, sheet} =
      GSS.Spreadsheet.Supervisor.spreadsheet(Application.fetch_env!(:fosfosol, :file_id))
    IO.inspect(fn ->
      {:ok, props} = GSS.Spreadsheet.properties(sheet)
      props["properties"]["title"]
    end.())
  end
end
