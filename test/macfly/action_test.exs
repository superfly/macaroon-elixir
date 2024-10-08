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

  describe "from_human/1" do
    test "can parse a single permission" do
      assert Action.read() == Action.from_human("r")
      assert Action.write() == Action.from_human("w")
      assert Action.create() == Action.from_human("c")
      assert Action.delete() == Action.from_human("d")
      assert Action.control() == Action.from_human("C")
    end

    test "can parse multiple permissions in arbitrary order" do
      assert %Action{read: true, write: true, delete: true, create: true, control: false} == Action.from_human("rwdc")
      assert %Action{control: true, read: true, delete: true, write: true, create: false} == Action.from_human("Crdw")
    end
  end

  describe "to_human/1" do
    test "can convert a permission to a human-readable string" do
      assert "r" == Action.to_human(Action.read())
      assert "w" == Action.to_human(Action.write())
      assert "c" == Action.to_human(Action.create())
      assert "d" == Action.to_human(Action.delete())
      assert "C" == Action.to_human(Action.control())
    end

    test "can convert multiple permissions to a human-readable string, in reliable order" do
      assert "rwcd" == Action.to_human(%Action{read: true, write: true, delete: true, create: true, control: false})
      assert "rwdC" == Action.to_human(%Action{control: true, read: true, delete: true, write: true, create: false})
      assert "rwcdC" == Action.to_human(Action.all())
    end
  end
end
