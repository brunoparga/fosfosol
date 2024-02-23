defmodule Fosfosol.Types do
  @moduledoc """
  Define types used by the application.
  """

  @typedoc """
  The front text of the flashcard. This should always be in the
  language that is being studied.
  """
  @type front_text :: String.t()
  @typedoc """
  The back text of the flashcard. This should always be in the
  language that is already known.
  """
  @type back_text :: String.t()
  @typedoc """
  A note ID in Anki. Even more so than for other values, Anki is the
  source of truth for this, as it is who generates the ID.
  """
  @type note_id :: integer()
end
