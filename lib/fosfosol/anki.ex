defmodule Fosfosol.Anki do
  @moduledoc """
  `Fosfosol.Anki` contains functions for the app to interact with Anki
  via AnkiConnect.
  """

  def read_ids do
    deck = Application.fetch_env!(:fosfosol, :deck_name)

    anki_os_pid =
      case System.cmd("pgrep", ["anki"]) do
        # If Anki is not yet open, open it
        {"", _} ->
          {:os_pid, anki_os_pid} = Port.open({:spawn, "anki"}, []) |> Port.info(:os_pid)
          Integer.to_string(anki_os_pid)

        {os_pid, 0} ->
          String.trim(os_pid)
      end

    {anki_os_pid, get_ids(deck)}
  end

  def add_flags(ids) do
    raw_notes = read_notes(ids)

    notes_without_flags =
      raw_notes
      |> Enum.map(&properize_note_no_deflag/1)
      |> Enum.reject(fn
        [front, back, _id] ->
          String.starts_with?(front, Application.fetch_env!(:fosfosol, :front_flag)) and
            String.starts_with?(back, Application.fetch_env!(:fosfosol, :back_flag))
      end)

    notes_without_flags
    |> Enum.map(&prepare_note_for_update/1)
    |> Enum.each(&AnkiConnect.update_note/1)

    {raw_notes |> Enum.map(&properize_note/1), notes_without_flags}
  end

  @spec get_ids(String.t()) :: list(integer())
  defp get_ids(deck) do
    get_ids(deck, 1)
  end

  @spec get_ids(String.t(), integer()) :: list(integer())
  defp get_ids(deck, timeout) do
    case AnkiConnect.find_notes(%{query: "deck:#{deck}"}) do
      {:ok, anki_ids} ->
        anki_ids

      {:error, _reason} ->
        Process.sleep(timeout)
        get_ids(deck, round(timeout * 1.5))
    end
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
          Front: "#{Application.fetch_env!(:fosfosol, :front_flag)}#{front}",
          Back: "#{Application.fetch_env!(:fosfosol, :back_flag)}#{back}"
        }
      }
    }
  end

  defp properize_note(note) do
    [
      :fosfosol.deflag(note["fields"]["Front"]["value"]),
      :fosfosol.deflag(note["fields"]["Back"]["value"]),
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
