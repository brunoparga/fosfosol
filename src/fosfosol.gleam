import gleam/string

pub fn deflag(text: String) {
  case string.split_once(text, on: " ") {
    Ok(#(_flag, word)) -> word
    Error(_) -> text
  }
}
