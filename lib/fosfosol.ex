defmodule Fosfosol do
  @moduledoc """
  Documentation for `Fosfosol`.
  """

  @doc """
  Run the synchronization between Google Spreadsheets and Anki.
  """
  def sync do
    IO.inspect(AnkiConnect.deck_names_and_ids())
  end
end
