defmodule Fosfosol.Types do
  @moduledoc """
  Define types used by the application.
  """

  @typep row_number :: integer()
  @typep front_text :: String.t()
  @typep back_text :: String.t()
  @typep note_id :: integer() | nil

  @typedoc """
  An existing note on Anki. TODO
  """
  # @type anki_note :: {front_text(), back_text(), note_id()}
  @type anki_note :: list(card_text() | note_id())

  @typedoc """
  A row in the spreadsheet, with its row, text fields, and a possible
  Anki ID of the corresponding note. `front_text` should always be in
  the language that is being studied, and `back_text` in the one that
  is already known.

  TODO: decide what to do about multiple users with different IDs for
  the same notes.
  """
  @type sheet_row :: {row_number(), front_text(), back_text(), note_id()}

  @typedoc """
  A card text that might be either the front or the back.
  """
  @type card_text :: front_text() | back_text()

  @typedoc """
  A JSON report that is used by the app to know what to do with each
  spreadsheet row and Anki note, and by the user to know what is
  going on.
  """

  @type report :: %{
          required(:errors) => list(error()),
          required(:flag_updates) => list(flag_update()),
          required(:new_flashcards | :sheet_rows) => list(sheet_row()),
          required(:note_count) => count(),
          required(:perfect_count) => count(),
          required(:row_count) => count(),
          required(:sheet_inserts) => list(sheet_insert()),
          required(:updates) => list(update())
        }

  @typep count :: integer()
  # TODO: refine all `term()` types
  @typep error() :: term()
  @typep flag_update() :: term()
  @typep sheet_insert() :: term()
  @typep update() :: term()
end
