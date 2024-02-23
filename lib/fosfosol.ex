defmodule Fosfosol do
  @moduledoc """
  Documentation for `Fosfosol`.
  """

  use Application
  alias Fosfosol.{Anki, Report, Sheets}

  def start(_type, _args) do
    sync()
    {:ok, self()}
  end

  @doc """
  Run the synchronization between Google Spreadsheets and Anki.
  """
  def sync do
    {writer, file} = Report.build_writer()

    # First of all we load just the IDs from Anki.
    anki_ids = Anki.read_ids()

    # One thing that is cheap and only requires interacting with Anki,
    # not Sheets, is to check if there are entries without flags. We
    # add them if necessary.
    #
    # We get back all of the notes in a format we need, for later.
    # TODO: also get back just the flag ones, for the report.
    anki_notes = Anki.add_flags(anki_ids, writer)

    # Now we load the rows from the spreadsheet.
    sheet = Sheets.load_sheet()
    sheet_rows = Sheets.read_rows(sheet)

    # Equipped with all this data, we compare the two sources.
    # We're looking for anything that might need to be inserted or
    # updated on either source. The ideal case is when IDs, fronts and
    # backs all match. There might be rows that need updated from Anki,
    # notes that are not even in the spreadsheet yet and need to be
    # inserted, and mismatches between the sources to handle manually.
    # There might also be sheet rows for which flashcards need to
    # be created.
    initial_report = %{
      sheet_rows: sheet_rows,
      perfect_count: 0,
      updates: [],
      sheet_inserts: [],
      errors: []
    }

    report =
      Enum.reduce(anki_notes, initial_report, &generate_report/2)
      # Sort the list of rows to make our lives easier.
      |> Map.update!(
        :updates,
        &Enum.sort(&1, fn row1, row2 -> row1 < row2 end)
      )

    # TODO: get rid of the writer – convert once to JSON and File.write! it.
    writer.(report)

    if length(report.updates) > 0 or length(report.sheet_inserts) > 0 do
      insert_notes_into_sheet(
        sheet,
        report.updates,
        report.sheet_inserts,
        elem(List.last(sheet_rows), 0)
      )
    end

    if length(report.sheet_rows) > 0,
      do: create_flashcards_and_update_ids(sheet, report.sheet_rows)

    :ok = File.close(file)
  end

  defp generate_report([note_front, note_back, note_id], report) do
    # Okay, so now we're iterating over Anki notes with the sheet rows
    # in context. For each note, we first find the number of the row
    # that corresponds to it. Since there might have been changes in
    # the source of truth (Anki), we look both for the row that matches
    # the front text and the back text of the flashcard, in the hope
    # that we will either get two matching values, or one value and
    # `nil`. Getting two different non-`nil` values is a problem.
    front_side_row = Enum.find(report.sheet_rows, &(elem(&1, 1) == note_front))
    back_side_row = Enum.find(report.sheet_rows, &(elem(&1, 2) == note_back))

    case {front_side_row, back_side_row} do
      {nil, nil} ->
        Map.update!(report, :sheet_inserts, &[[note_front, note_back, note_id] | &1])

      {row, row} when not is_nil(elem(row, 3)) ->
        Map.update!(report, :perfect_count, &(&1 + 1))
        |> Map.update!(:sheet_rows, &Enum.reject(&1, fn row -> row == front_side_row end))

      {row, row} ->
        # row your boat gently down the Stream
        # merrily, merrily, merrily, merrily
        # you've just crashed the BEAM
        Map.update!(report, :updates, &[{elem(row, 0), note_front, note_back, note_id} | &1])
        |> Map.update!(:sheet_rows, &Enum.reject(&1, fn row -> row == front_side_row end))

      {row, nil} ->
        # TODO: let the user decide the source of truth in case of conflict
        Map.update!(report, :updates, &[{elem(row, 0), note_front, note_back, note_id} | &1])
        |> Map.update!(:sheet_rows, &Enum.reject(&1, fn row -> row == front_side_row end))

      {nil, row} ->
        Map.update!(report, :updates, &[{elem(row, 0), note_front, note_back, note_id} | &1])
        |> Map.update!(:sheet_rows, &Enum.reject(&1, fn row -> row == back_side_row end))

      {_something, _something_else} ->
        element = %{
          front: %{text: note_front, row: front_side_row},
          back: %{text: note_back, row: back_side_row}
        }

        Map.update!(report, :errors, &[element | &1])
        |> Map.update!(:sheet_rows, &Enum.reject(&1, fn row -> row == front_side_row end))
        |> Map.update!(:sheet_rows, &Enum.reject(&1, fn row -> row == back_side_row end))
    end
  end

  defp insert_notes_into_sheet(sheet, updates, inserts, last_row) do
    ranges = Enum.map(updates, fn {row, _, _, _} -> "A#{row}:C#{row}" end)
    values = Enum.map(updates, &tl(Tuple.to_list(&1)))

    update_data =
      case values do
        [] ->
          []

        data ->
          GSS.Spreadsheet.write_rows(sheet, ranges, values)
          IO.puts("Should have updated #{length(ranges)} existing spreadsheet rows.")
          data
      end

    insert_data =
      case inserts do
        [] ->
          []

        data ->
          GSS.Spreadsheet.append_rows(sheet, last_row + 1, inserts)
          IO.puts("Should have added #{length(inserts)} new rows to spreadsheet.")
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
      |> Enum.map(fn {row, id} -> put_elem(row, 3, id) end)

    insert_notes_into_sheet(sheet, updates, [], 320)
  end

  defp build_flashcard({_row, front, back, nil}) do
    base =
      "./config/settings.json"
      |> File.read!()
      |> Jason.decode!(keys: :atoms)
      |> Map.drop(~w[front back file_id last_updated]a)

    Map.put(base, :fields, %{Front: enflag(:front, front), Back: enflag(:back, back)})
  end

  defp enflag(side, text) do
    flag = Keyword.fetch!(Application.fetch_env!(:fosfosol, side).values, :flag)
    "#{flag} #{text}"
  end
end
