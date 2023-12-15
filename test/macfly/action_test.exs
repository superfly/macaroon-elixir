defmodule Macfly.ActionTest do
  use ExUnit.Case

  alias Macfly.Action

  test "numbers line up correctly" do
    assert 1 == Action.read() |> Action.to_wire()
    assert 2 == Action.write() |> Action.to_wire()
    assert 4 == Action.create() |> Action.to_wire()
    assert 8 == Action.delete() |> Action.to_wire()
    assert 16 == Action.control() |> Action.to_wire()
  end
end
