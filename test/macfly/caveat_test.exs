# defmodule Macfly.CaveatTest do
#   use ExUnit.Case

#   test "foo" do
#     cavs = [Macfly.Caveat.ValidityWindow.build(for: 123)]

#     {:ok, cavs2} =
#       cavs
#       |> Macfly.LowLevel.caveats_to_wire()
#       |> Macfly.Caveat.Registry.from_wire()

#     assert cavs == cavs2
#   end
# end
