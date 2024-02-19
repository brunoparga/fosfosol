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
      GSS.Spreadsheet.Supervisor.spreadsheet("1cwUCmUNgPZqoWQC8x_0LDLcf0u9sWjdMvRXg4w8LFuE")
    IO.inspect(GSS.Spreadsheet.properties(sheet))
  end
end
