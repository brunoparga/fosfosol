# Fosfosol

`Fosfosol`, named after an arcane pharmaceutical concoction that's supposed to aid memory, is a connector between an Anki flashcard deck and a Google Spreadsheet. The idea is to allow several students in a language class to all add words to the spreadsheet and then each generate flashcards to use on Anki.

## Installation

**TODO: document how to configure and run the app**

## Roadmap

### Functionality improvements

* Make the app properly interactive
* Check at startup whether the API key exists and teach the user to create one if not
* Check at startup if the API key is allowed to talk to the sheet and fix it if not
* Check at the beginning if the user wants Anki open or closed at the end
* Interactive mode (confirm everything) vs non-interactive one
* Allow multi-step/Cloze notes (e.g. for different noun/verb base forms, or abbreviations)

### Bug fixes and code improvements

* The numbers reported by the app run don't match the JSON report or what actually happens. E.g. the note "pime (b-)/blind" is in the report but not changed in the sheet.
* Write automated tests
* Port data processing to Gleam, leaving Elixir as the scripting glue
