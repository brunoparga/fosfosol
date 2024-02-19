defmodule Mix.Tasks.Fosfosol do
  @moduledoc "Run the Anki-Google Spreadsheet synchronizer"
  @shortdoc "Run the Anki-Google Spreadsheet synchronizer"

  use Mix.Task

  def run(_args) do
    Fosfosol.sync()
  end
end
