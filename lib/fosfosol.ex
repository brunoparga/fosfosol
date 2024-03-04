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
  alias Fosfosol.Types, as: T

  @sigquit "-3"

  def start(_type, _args) do
    :ok = sync()
    {:ok, self()}
  end

  @doc """
  Run the synchronization between Google Spreadsheets and Anki.
  """
  def sync do
    # First of all we load just the IDs from Anki.
    {anki_os_pid, anki_ids} = Anki.read_ids()

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
    |> insert_flashcards(sheet)
    |> insert_sheet_rows_from_anki(sheet)
    |> update_sheet_rows_from_anki(sheet)
    |> format_updates()
    |> write_report()
    |> Sheets.sort(sheet)

    System.cmd("kill", [@sigquit, anki_os_pid])
    :ok
  end

  defp insert_flashcards(%{new_flashcards: []} = report, _sheet), do: report

  defp insert_flashcards(%{new_flashcards: new_flashcards} = report, sheet) do
    # TODO: encapsulate the next lines in an Anki module function
    notes = Enum.map(new_flashcards, &Data.build_flashcard/1)
    {:ok, new_flashcard_ids} = AnkiConnect.add_notes(%{notes: notes})
    IO.puts("Should have created #{length(new_flashcards)} new Anki notes.")

    # TODO: `reduce` (pun intended) the number of calls to Enum
    # functions to just one
    updates =
      new_flashcards
      |> Enum.zip(new_flashcard_ids)
      |> Enum.map(fn {row, id} -> put_elem(row, 3, id) end)

    ranges = Enum.map(updates, fn {row, _, _, _} -> "A#{row}:C#{row}" end)
    values = Enum.map(updates, &tl(Tuple.to_list(&1)))

    GSS.Spreadsheet.write_rows(sheet, ranges, values)
    # The report only needs the words, not their row numbers or IDs.
    Map.put(report, :new_flashcards, Enum.slice(values, 0..2))
  end

  defp insert_sheet_rows_from_anki(%{sheet_inserts: []} = report, _sheet), do: report

  defp insert_sheet_rows_from_anki(report, sheet) do
    # We add two to the row count: one is for the sheet's header row and
    # one so that the append happens *after* the last existing row.
    GSS.Spreadsheet.append_rows(sheet, report.row_count + 2, report.sheet_inserts)
    IO.puts("Should have added #{length(report.sheet_inserts)} new rows to spreadsheet.")
    report
  end

  defp update_sheet_rows_from_anki(%{sheet_updates: []} = report, _sheet), do: report

  defp update_sheet_rows_from_anki(%{sheet_updates: updates} = report, sheet) do
    ranges = Enum.map(updates, fn {row, _, _, _} -> "A#{row}:C#{row}" end)
    values = Enum.map(updates, &tl(Tuple.to_list(&1)))

    GSS.Spreadsheet.write_rows(sheet, ranges, values)
    IO.puts("Should have updated #{length(ranges)} existing spreadsheet rows.")
    report
  end

  defp format_updates(report) do
    row_tuple_to_list = fn row -> tl(Tuple.to_list(row)) end
    change = fn updated_rows -> Enum.map(updated_rows, row_tuple_to_list) end
    Map.update!(report, :sheet_updates, change)
  end

  @spec write_report(T.report()) :: :ok
  defp write_report(report) do
    File.write!("./config/sync_report.json", Jason.encode!(report, pretty: true))
    report
  end
end
