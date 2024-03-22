import gleam/string

@external(erlang, "Elixir.Fosfosol.Data", "get_app_env")
pub fn app_env(key: Flag) -> String

pub type CardSide {
  Front
  Back
}

pub type Flag {
  FrontFlag
  BackFlag
}

pub type CardText = String

pub fn deflag(text: CardText) -> CardText {
  case string.split_once(text, on: " ") {
    Ok(#(_flag, word)) -> word
    Error(_) -> text
  }
}

pub fn enflag(flag_side: Flag, text: CardText) -> CardText {
  let flag = app_env(flag_side)
  flag <> text
}
