defmodule Macfly.MapFixTest do
  use ExUnit.Case

  @numeric_struct %{3 => :c, 1 => :a, 2 => :b}
  @numeric_fragment Msgpax.Fragment.new([
                      131,
                      [1],
                      [161 | "a"],
                      [2],
                      [161 | "b"],
                      [3],
                      [161 | "c"]
                    ])

  @atom_struct %{c: :c, a: :a, b: :b}
  @atom_fragment Msgpax.Fragment.new([
                   131,
                   [161 | "a"],
                   [161 | "a"],
                   [161 | "b"],
                   [161 | "b"],
                   [161 | "c"],
                   [161 | "c"]
                 ])

  @string_struct %{"c" => :c, "a" => :a, "b" => :b}
  @string_fragment Msgpax.Fragment.new([
                     131,
                     [161 | "a"],
                     [161 | "a"],
                     [161 | "b"],
                     [161 | "b"],
                     [161 | "c"],
                     [161 | "c"]
                   ])

  test "doesn't mess with non-maps" do
    assert nil == Macfly.MapFix.traverse(nil)
    assert 1 == Macfly.MapFix.traverse(1)
    assert 1.1 == Macfly.MapFix.traverse(1.1)
    assert "foo" == Macfly.MapFix.traverse("foo")
    assert :foo == Macfly.MapFix.traverse(:foo)
    assert [1, :two, "three"] == Macfly.MapFix.traverse([1, :two, "three"])
  end

  test "converts top-level maps" do
    assert @numeric_fragment == Macfly.MapFix.traverse(@numeric_struct)
    assert @atom_fragment == Macfly.MapFix.traverse(@atom_struct)
    assert @string_fragment == Macfly.MapFix.traverse(@string_struct)
  end

  test "converts maps in arrays" do
    assert [3, @numeric_fragment, 1, 2] == Macfly.MapFix.traverse([3, @numeric_struct, 1, 2])
    assert [3, @atom_fragment, 1, 2] == Macfly.MapFix.traverse([3, @atom_struct, 1, 2])
    assert [3, @string_fragment, 1, 2] == Macfly.MapFix.traverse([3, @string_struct, 1, 2])
  end

  test "converts maps in map values" do
    assert Msgpax.Fragment.new([129, [161 | "a"], @numeric_fragment.data]) ==
             Macfly.MapFix.traverse(%{"a" => @numeric_struct})

    assert Msgpax.Fragment.new([129, [161 | "a"], @atom_fragment.data]) ==
             Macfly.MapFix.traverse(%{"a" => @atom_struct})

    assert Msgpax.Fragment.new([129, [161 | "a"], @string_fragment.data]) ==
             Macfly.MapFix.traverse(%{"a" => @string_struct})
  end
end
