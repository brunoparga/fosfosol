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
    proper_notes = Enum.map(notes, &properize_note/1)

    [notes_with_row_numbers, missing_from_spreadsheet, errors] =
      Enum.map(proper_notes, fn
        %{front: note_front, back: note_back, id: note_id} ->
          # search db rows to include the corresponding row ID in these maps
          front_side_row = Enum.find_value(sheet_rows, finder(1, note_front))
          back_side_row = Enum.find_value(sheet_rows, finder(2, note_back))
          comparison = compare(front_side_row, back_side_row)

          case comparison do
            :missing ->
              {:missing, [note_front, note_back, note_id]}

            :error ->
              {:error,
               "Anki note \"#{note_front}\" (#{front_side_row})/\"#{note_back}\" (#{back_side_row})found different matches in the spreadsheet."}

            :front ->
              {:ok, [front_side_row, note_front, note_back, note_id]}

            :back ->
              {:ok, [back_side_row, note_front, note_back, note_id]}

            _ ->
              {:error, "Unknown error"}
          end
      end)
      |> Enum.reduce([[], [], []], fn
        {:ok, value}, [hits, missing, errors] -> [[value | hits], missing, errors]
        {:missing, value}, [hits, missing, errors] -> [hits, [value | missing], errors]
        {:error, reason}, [hits, missing, errors] -> [hits, missing, [reason | errors]]
      end)
      |> Enum.map(&Enum.reverse/1)

    # {_rows, } = missing_from_spreadsheet
    # # |> Enum.reduce
    # |> IO.inspect()
    IO.inspect(notes_with_row_numbers)
  end

  defp deflag(binary) do
    [_flag, text] = String.split(binary, " ", parts: 2)
    text
  end

  defp properize_note(note) do
    %{
      id: note["noteId"],
      front: deflag(note["fields"]["Front"]["value"]),
      back: deflag(note["fields"]["Back"]["value"])
    }
  end

  defp compare(front, back) do
    cond do
      front == nil and back == nil -> :missing
      front && back && front != back -> :error
      front -> :front
      back -> :back
    end
  end

  defp finder(position, needle) do
    fn row -> if Enum.at(row, position) == needle, do: hd(row) end
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
        Enum.reduce(raw_rows, {List.first(indexes_chunk), []}, fn
          row, {count, list} ->
            {count + 1, [[count | row] | list]}
        end)

      rows ++ Enum.reverse(chunk_rows)
    end
  end
end
