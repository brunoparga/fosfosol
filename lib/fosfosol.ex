defmodule Fosfosol do
  @moduledoc """
  Documentation for `Fosfosol`.
  """

  use Application
  alias GSS.Spreadsheet, as: Sheet

  def start(_type, _args) do
    sync()
    {:ok, self()}
  end

  @doc """
  Run the synchronization between Google Spreadsheets and Anki.
  """
  def sync do
    {:ok, sheet} =
      Sheet.Supervisor.spreadsheet(Application.fetch_env!(:fosfosol, :file_id))

    {:ok, anki_ids} = AnkiConnect.find_notes(%{query: "deck:M-224"})

    sheet_rows = read_sheet_ids(sheet)

    sheet_ids =
      sheet_rows
      |> Enum.reduce([], fn
        [_row_number, _front, _back, id], acc -> [String.to_integer(id) | acc]
        _no_id, acc -> acc
      end)
      |> Enum.reverse()

    sheet_needs_id = anki_ids -- sheet_ids
    # anki_needs_cards = Enum.reject(sheet_rows, fn
    #   # [row_number, front, back, id]
    #   # if there is no ID, the length of the row is 3
    #   row -> length(row) == 4
    # end)
    {:ok, notes} = AnkiConnect.notes_info(%{notes: sheet_needs_id})

    _proper_notes = Enum.map(notes, fn note ->
      %{
        id: note["noteId"],
        front: note["fields"]["Front"]["value"],
        back: note["fields"]["Back"]["value"]
      }
    end)
  end

  defp read_sheet_ids(sheet) do
    {:ok, row_count} = Sheet.rows(sheet)

    2..row_count
    |> Enum.chunk_every(250)
    |> Enum.reduce([], read_chunk(sheet))
  end

  defp read_chunk(sheet) do
    fn indexes_chunk, rows ->
      start_range = List.first(indexes_chunk)
      end_range = List.last(indexes_chunk)

      {:ok, raw_rows} =
        Sheet.read_rows(
          sheet,
          start_range,
          end_range,
          timeout: 20_000
        )

      {_count, chunk_rows} =
        Enum.reduce(raw_rows, {0, []}, fn
          row, {count, list} ->
            {count + 1, [[count + 1 | row] | list]}
        end)

      rows ++ Enum.reverse(chunk_rows)
    end
  end
end
