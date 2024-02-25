defmodule Fosfosol do
  @moduledoc """
  `Fosfosol`, named after an arcane pharmaceutical concoction that's
  supposed to aid memory, is a connector between an Anki flashcard deck
  and a Google Spreadsheet. The idea is to allow several students in a
  language class to all add words to the spreadsheet and then each
  generate flashcards to use on Anki.
  """

  use Application
  alias Fosfosol.{Anki, Data, Sheets}

  def start(_type, _args) do
    :ok = sync()
    {:ok, self()}
  end

  @doc """
  Run the synchronization between Google Spreadsheets and Anki.
  """
  def sync do
    # First of all we load just the IDs from Anki.
    anki_ids = Anki.read_ids()

    # One thing that is cheap and only requires interacting with Anki,
    # not Sheets, is to check if there are entries without flags. We
    # add them if necessary.
    #
    # We get back all of the notes in a format we need, for later.
    notes = Anki.add_flags(anki_ids)

    # Now we load the rows from the spreadsheet.
    # TODO: add a timestamp check to maybe skip this API call.
    sheet = Sheets.load_sheet()
    sheet_rows = Sheets.read_rows(sheet)

    Data.build_report(notes, sheet_rows)
    |> do_sync(sheet)
    |> Map.update!(:updates, fn updates -> Enum.map(updates, &tl(Tuple.to_list(&1))) end)
    |> write_report()
  end

  defp do_sync(%{updates: [], sheet_inserts: [], new_flashcards: []} = report, _sheet), do: report

  defp do_sync(%{updates: [], sheet_inserts: [], new_flashcards: new_flashcards} = report, sheet) do
    create_flashcards_and_update_ids(sheet, new_flashcards)
    report
  end

  defp do_sync(%{new_flashcards: []} = report, sheet) do
    sync_sheet(
      sheet,
      report.updates,
      report.sheet_inserts,
      report.row_count
    )

    report
  end

  defp do_sync(report, sheet) do
    sync_sheet(
      sheet,
      report.updates,
      report.sheet_inserts,
      report.row_count
    )

    create_flashcards_and_update_ids(sheet, report.new_flashcards)
    report
  end

  defp write_report(report) do
    File.write!("./config/sync_report.json", Jason.encode!(report, pretty: true))
  end

  defp sync_sheet(sheet, updates, inserts, row_count) do
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
          # We add two to the row count: one is for the sheet's header
          # row and one so that the append happens *after* the last
          # existing row.
          GSS.Spreadsheet.append_rows(sheet, row_count + 2, inserts)
          IO.puts("Should have added #{length(inserts)} new rows to spreadsheet.")
          data
      end

    {update_data, insert_data}
  end

  defp create_flashcards_and_update_ids(sheet, rows) do
    # TODO: encapsulate the next two lines in an Anki module function
    notes = Enum.map(rows, &Data.build_flashcard/1)
    {:ok, new_flashcard_ids} = AnkiConnect.add_notes(%{notes: notes})

    # TODO: the report doesn't know how to distinguish updates that are
    # text corrections from the ones that are new flashcards.
    updates =
      rows
      |> Enum.zip(new_flashcard_ids)
      |> Enum.map(fn {row, id} -> put_elem(row, 3, id) end)

    sync_sheet(sheet, updates, [], 320)
  end
end
