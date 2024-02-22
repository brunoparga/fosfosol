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
    case File.rm("./report") do
      :ok -> :ok
      {:error, _reason} -> :ok
    end

    file = File.open!("./report", [:append, :utf8])
    write = build_writer(file)

    {:ok, sheet} =
      Sheet.Supervisor.spreadsheet(Application.fetch_env!(:fosfosol, :file_id))

    sheet_rows = read_sheet_rows(sheet)
    # first we figure out which words are in the spreadsheet but not Anki
    anki_needs_cards =
      Enum.reject(sheet_rows, fn
        # [row_number, front, back, id]
        # if there is no ID, the length of the row is 3
        row -> length(row) == 4
      end)

    write.("Words in Sheets but not Anki:")
    write.(anki_needs_cards)

    # Then we figure out which rows in the spreadsheet have flashcards
    # but the corresponding ID is not in the sheet. We do that by excluding
    # the IDs *present* in the sheet from the list of Anki IDs.
    {:ok, anki_ids} = AnkiConnect.find_notes(%{query: "deck:M-224"})

    sheet_ids =
      sheet_rows
      |> Enum.reduce([], fn
        [_row_number, _front, _back, id], acc -> [String.to_integer(id) | acc]
        _no_id, acc -> acc
      end)
      |> Enum.reverse()

    sheet_needs_id = anki_ids -- sheet_ids

    # Once we know the IDs present on Anki but not Sheets, we load their
    # content from Anki as a source of truth.
    {:ok, notes} = AnkiConnect.notes_info(%{notes: sheet_needs_id})
    proper_notes = Enum.map(notes, &properize_note/1)

    # Equipped with that data, we figure out whether it is just the ID that's
    # missing from the sheet, or the whole word, or if something's amiss.
    [notes_with_row_numbers, missing_from_spreadsheet, errors] =
      Enum.map(proper_notes, workhorse(sheet_rows))
      |> Enum.reduce([[], [], []], fn
        {:ok, value}, [hits, missing, errors] -> [[value | hits], missing, errors]
        {:missing, value}, [hits, missing, errors] -> [hits, [value | missing], errors]
        {:error, reason}, [hits, missing, errors] -> [hits, missing, [reason | errors]]
      end)
      |> Enum.map(&Enum.reverse/1)

    notes_with_row_numbers =
      notes_with_row_numbers
      |> Enum.sort(fn [row1 | _rest1], [row2 | _rest2] -> row1 < row2 end)

    write.("Notes with row numbers:")
    write.(notes_with_row_numbers)
    write.("Notes missing from the spreadsheet:")
    write.(missing_from_spreadsheet)
    write.("Errors:")
    write.(errors)
    :ok = File.close(file)

    if length(notes_with_row_numbers) > 0 or length(missing_from_spreadsheet) > 0 do
      write.("Inserting and updating into the sheet")

      insert_notes_into_sheet(
        sheet,
        notes_with_row_numbers,
        missing_from_spreadsheet,
        hd(List.last(sheet_rows))
      )
      |> write.()
    end

    if length(anki_needs_cards) > 0, do: create_flashcards_and_update_ids(sheet, anki_needs_cards)
  end

  defp insert_notes_into_sheet(sheet, updates, inserts, last_row) do
    ranges = Enum.map(updates, fn [row | _data] -> "A#{row}:C#{row}" end)
    values = Enum.map(updates, &tl/1)

    update_data =
      case Sheet.write_rows(sheet, ranges, values) do
        {:ok, data} ->
          IO.puts("Should have written #{length(ranges)} IDs to spreadsheet.")
          data

        {:error, exception} ->
          Exception.format(:error, exception)
      end

    insert_data =
      case Sheet.append_rows(sheet, last_row + 1, inserts) do
        {:error, exception} ->
          Exception.format(:error, exception)

        data ->
          IO.puts("Should have appent #{inserts.length} rows to spreadsheet.")
          data
      end

    {update_data, insert_data}
  end

  defp create_flashcards_and_update_ids(sheet, rows) do
    notes = Enum.map(rows, &build_flashcard/1)
    {:ok, new_flashcard_ids} = AnkiConnect.add_notes(%{notes: notes})

    updates =
      rows
      |> Enum.zip(new_flashcard_ids)
      |> Enum.map(fn {row, id} -> row ++ [id] end)

    insert_notes_into_sheet(sheet, updates, [], 320)
  end

  defp build_flashcard([_row, front, back]) do
    base =
      "./config/settings.json"
      |> File.read!()
      |> Jason.decode!(keys: :atoms)
      |> Map.drop(~w[front back file_id last_updated]a)

    Map.put(base, :fields, %{Front: front, Back: back})
  end

  defp workhorse(sheet_rows) do
    fn [note_front, note_back, note_id] ->
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
    end
  end

  defp build_writer(file) do
    fn contents ->
      options = [limit: :infinity, printable_limit: :infinity]
      IO.inspect(file, contents, options)
    end
  end

  defp deflag(binary) do
    [_flag, text] = String.split(binary, " ", parts: 2)
    text
  end

  defp properize_note(note) do
    [
      deflag(note["fields"]["Front"]["value"]),
      deflag(note["fields"]["Back"]["value"]),
      note["noteId"]
    ]
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

  defp read_sheet_rows(sheet) do
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
