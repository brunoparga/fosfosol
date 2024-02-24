defmodule Fosfosol.Anki do
  @moduledoc """
  `Fosfosol.Anki` contains functions for the app to interact with Anki
  via AnkiConnect.
  """

  def read_ids do
    # TODO: add an easy way to switch between test and production mode
    # {:ok, anki_ids} = AnkiConnect.find_notes(%{query: "deck:Test"})
    {:ok, anki_ids} = AnkiConnect.find_notes(%{query: "deck:M-224"})
    anki_ids
  end

  def add_flags(ids) do
    raw_notes = read_notes(ids)

    notes_without_flags =
      raw_notes
      |> Enum.map(&properize_note_no_deflag/1)
      |> Enum.reject(fn
        [front, back, _id] -> String.starts_with?(front, "🇪🇪") and String.starts_with?(back, "🏴󠁧󠁢󠁥󠁮󠁧󠁿")
      end)

    notes_without_flags
    |> Enum.map(&prepare_note_for_update/1)
    |> Enum.each(&AnkiConnect.update_note/1)

    {raw_notes |> Enum.map(&properize_note/1), notes_without_flags}
  end

  defp read_notes(ids) do
    {:ok, raw_notes} = AnkiConnect.notes_info(%{notes: ids})
    raw_notes
  end

  defp prepare_note_for_update([front, back, id]) do
    %{
      note: %{
        id: id,
        fields: %{
          Front: "🇪🇪 #{front}",
          Back: "🏴󠁧󠁢󠁥󠁮󠁧󠁿 #{back}"
        }
      }
    }
  end

  defp deflag(binary) do
    case String.split(binary, " ", parts: 2) do
      [_flag, text] -> text
      [text] -> text
    end
  end

  defp properize_note(note) do
    [
      deflag(note["fields"]["Front"]["value"]),
      deflag(note["fields"]["Back"]["value"]),
      note["noteId"]
    ]
  end

  defp properize_note_no_deflag(note) do
    [
      note["fields"]["Front"]["value"],
      note["fields"]["Back"]["value"],
      note["noteId"]
    ]
  end
end
