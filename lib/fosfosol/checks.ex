defmodule Fosfosol.Checks do
  @moduledoc """
  Checks that should be performed every time the app starts.
  """

  @doc """
  Check if there is a settings file and creates it if not
  """
  def check_settings do
    case File.exists?("config/prod_settings.json") do
      true -> true
      false -> create_settings_file()
    end
  end

  def check_api_key do
    true
  end

  def check_sheets_access do
    true
  end

  def check_not_too_recent do
    true
  end

  defp create_settings_file do
    # TODO: allow user to choose a different card model
    settings =
      %{environment: "prod", model_name: "Basic (and reversed card)", last_updated: ""}
      |> get_deck_name()
      |> get_url()
      |> get_flags()

    File.write!("./config/prod_settings.json", Jason.encode!(settings, pretty: true))
  end

  defp get_deck_name(settings) do
    message = "What is your Anki deck called?\n(Please create one if it doesn't exist yet) > "
    Map.put(settings, :deck_name, IO.gets(message) |> String.trim())
  end

  defp get_url(settings) do
    message =
      "What is the address of your Google spreadsheet?\nIt must be something like:\nhttps://docs.google.com/spreadsheets/d/[ #{IO.ANSI.format([:italic, :blue, "a long sequence of letters and numbers"])} ]/edit#gid=0\n(Please paste it here) > "

    Map.put(settings, :file_id, IO.gets(message) |> process_url())
  end

  defp process_url(url) do
    format =
      Regex.compile!("https://docs.google.com/spreadsheets/d/[A-Za-z0-9_-]+/edit.*", [:ungreedy])

    case Regex.run(format, url) do
      nil ->
        new_url = IO.gets("Invalid URL. Please copy the Google Spreadsheet URL here exactly > ")
        process_url(new_url)

      [match] ->
        match
    end
  end

  defp get_flags(settings) do
    message =
      "Fosfosol uses flag emojis to distinguish words that are spelled the same\nin the language you are studying and the one you already know (for\nexample, if studying Spanish from English you'd have the cards\n'🇪🇸 soy/🇬🇧 I am' and also '🇪🇸 soja/🇬🇧 soy'). Do you want to use flags in your flashcards?\n(Please enter 'yes' or 'no', or just hit Enter for yes) > "

    case IO.gets(message) |> String.trim() do
      "no" -> Map.merge(settings, %{front_flag: "", back_flag: ""})
      _ -> do_get_flags(settings)
    end
  end

  defp do_get_flags(settings) do
    Map.merge(settings, %{
      front_flag:
        IO.gets("Please enter the flag emoji for the language you are learning > ")
        |> String.trim(),
      back_flag:
        IO.gets("Please enter the flag emoji for the language you already know > ")
        |> String.trim()
    })
  end
end
