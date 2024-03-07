defmodule FosfosolTest do
  use ExUnit.Case
  doctest Fosfosol

  test "can call Gleam code" do
    hello = "HELLO GLEAM"
    assert :fosfosol.deflag(hello) == "GLEAM"
  end
end
