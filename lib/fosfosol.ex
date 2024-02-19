defmodule Fosfosol do
  @moduledoc """
  Documentation for `Fosfosol`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Fosfosol.hello()
      :world

  """
  def hello do
    :world
  end

  @doc """
  Run the synchronization between Google Spreadsheets and Anki.
  """
  def run do
    AnkiConnect.deck_names_and_ids()
  end
end
