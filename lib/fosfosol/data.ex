defmodule Fosfosol.Data do
  @moduledoc """
  Handle all operations that consist only of moving data around in
  memory, without contacting either external source.
  """

  alias Fosfosol.Types, as: T

  @typep flashcard_insert :: term()

  @spec build_report({T.anki_note(), T.anki_note()}, list(T.sheet_row())) :: T.report()
  def build_report({anki_notes, notes_without_flags}, sheet_rows) do
    # Equipped with all the data from both sources, we compare them.
    # We're looking for anything that might need to be inserted or
    # updated on either source. The ideal case is when IDs, fronts and
    # backs all match. There might be rows that need updated from Anki,
    # notes that are not even in the spreadsheet yet and need to be
    # inserted, and mismatches between the sources to handle manually.
    # There might also be sheet rows for which flashcards need to
    # be created.
    initial_report = %{
      environment: Application.fetch_env!(:fosfosol, :environment),
      errors: [],
      flag_updates: notes_without_flags,
      note_count: length(anki_notes),
      perfect_count: 0,
      row_count: length(sheet_rows),
      sheet_inserts: [],
      sheet_rows: sheet_rows,
      sheet_updates: []
    }

    Enum.reduce(anki_notes, initial_report, &generate_report/2)
    # Sort the list of rows to make our lives easier.
    |> Map.update!(
      :sheet_updates,
      &Enum.sort(&1, fn row1, row2 -> row1 < row2 end)
    )
    |> then(&Map.put(&1, :new_flashcards, &1.sheet_rows))
    |> then(&Map.drop(&1, [:sheet_rows]))
  end

  # TODO: improve this anki_note type – it needs to be a tuple,
  # rather than a list of mixed types
  @spec generate_report(T.anki_note(), T.report()) :: T.report()
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
        Map.update!(report, :sheet_updates, &[{elem(row, 0), note_front, note_back, note_id} | &1])
        |> Map.update!(:sheet_rows, &Enum.reject(&1, fn row -> row == front_side_row end))

      {row, nil} ->
        # TODO: let the user decide the source of truth in case of conflict
        Map.update!(report, :sheet_updates, &[{elem(row, 0), note_front, note_back, note_id} | &1])
        |> Map.update!(:sheet_rows, &Enum.reject(&1, fn row -> row == front_side_row end))

      {nil, row} ->
        Map.update!(report, :sheet_updates, &[{elem(row, 0), note_front, note_back, note_id} | &1])
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

  @spec build_flashcard(T.sheet_row()) :: flashcard_insert()
  def build_flashcard({_row, front, back, nil}) do
    base =
      "./config/settings.json"
      |> File.read!()
      |> Jason.decode!(keys: :atoms)
      |> Map.drop(~w[front back file_id last_updated]a)

    Map.put(base, :fields, %{Front: enflag(:front, front), Back: enflag(:back, back)})
  end

  @spec enflag(:front | :back, T.card_text()) :: T.card_text()
  defp enflag(side, text) do
    flag = Keyword.fetch!(Application.fetch_env!(:fosfosol, side).values, :flag)
    "#{flag} #{text}"
  end
end
