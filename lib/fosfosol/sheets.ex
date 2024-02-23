defmodule Fosfosol.Sheets do
  @moduledoc """
  Handle the interaction between Fosfosol and Google Spreadsheets.
  """

  alias Fosfosol.Types, as: T
  alias GSS.Spreadsheet, as: GSS

  @typep sheet :: pid
  @typep row_number :: integer()
  @typep raw_row :: list(String.t())
  @typep row :: {row_number(), T.front_text(), T.back_text(), T.note_id() | nil}

  @doc """
  Return a `pid` that is used to interact with the Google Spreadsheet.
  """
  @spec load_sheet() :: sheet()
  def load_sheet do
    # TODO: add an easy way to switch between test and production mode
    # {:ok, sheet_pid} = GSS.Supervisor.spreadsheet("1vucaFV3YGADgxyN7o3gW1cuaM6Hf3xK-41mTiMGsobs")
    {:ok, sheet_pid} = GSS.Supervisor.spreadsheet(Application.fetch_env!(:fosfosol, :file_id))
    sheet_pid
  end

  @doc """
  Read all of the rows from a given spreadsheet `pid` and return them
  as tuples containing the row number, front text, back text and Anki ID.
  If there is no ID yet (either the flashcard is missing or it was created
  but its ID was not set in the sheet), then the corresponding field
  is `nil`.
  """
  @spec read_rows(sheet) :: list(row())
  def read_rows(sheet) do
    {:ok, row_count} = GSS.rows(sheet, timeout: 20_000)

    # TODO: un-hardcode this number 2; the number of header rows might be >1,
    # and this should be either set in the app's config or, better yet, read
    # from the spreadsheet itself.
    2..row_count
    |> Enum.chunk_every(250)
    |> Enum.reduce([], read_chunk(sheet))
    |> Enum.reverse()
  end

  _ = """
  Read a chunk of up to 250 rows from the spreadsheet.
  TODO: this might error if the number of rows to read equals 1 mod 250,
  as it is unclear whether `GSS.read_rows` supports the start and end of
  the range being identical. For now, ¯\_(ツ)_/¯
  """

  @spec read_chunk(sheet) :: (list(number()), list(row()) -> list(row()))
  defp read_chunk(sheet) do
    fn chunk, acc ->
      chunk_start = List.first(chunk)
      chunk_end = List.last(chunk)
      {:ok, raw_rows} = GSS.read_rows(sheet, chunk_start, chunk_end, timeout: 20_000)
      chunk_rows = format_rows(raw_rows, chunk_start)
      chunk_rows ++ acc
    end
  end

  _ = """
  Make two necessary changes to the data received from the spreadsheet:

      I. include the row number, as that is necessary for reference
      II. represent the note ID as an integer, for consistency

  This also changes the type of the row from a list of strings to a tuple.
  """

  @spec format_rows(list(raw_row()), integer()) :: list(row())
  defp format_rows(raw_rows, chunk_start) do
    formatter = fn raw_row, {count, list} ->
      new_row = build_new_row(raw_row, count)
      {count + 1, [new_row | list]}
    end

    {_count, chunk_rows} = Enum.reduce(raw_rows, {chunk_start, []}, formatter)
    chunk_rows
  end

  defp build_new_row([front, back, id], count), do: {count, front, back, String.to_integer(id)}
  defp build_new_row([front, back], count), do: {count, front, back, nil}
end
