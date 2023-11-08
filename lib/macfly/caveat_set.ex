defmodule Macfly.CaveatSet do
  alias Macfly.CaveatTypes
  alias Macfly.Caveat

  def from_wire([type, body | rest], %CaveatTypes{} = t) when is_integer(type) do
    with {:ok, rest} <- from_wire(rest, t),
         {:ok, caveat} <- CaveatTypes.build_caveat(t, type, body) do
      {:ok, [caveat | rest]}
    else
      error -> error
    end
  end

  def from_wire([], %CaveatTypes{}), do: {:ok, []}
  def from_wire([_], %CaveatTypes{}), do: {:error, "bad caveat set format"}

  def to_wire([caveat | rest]) do
    [Caveat.type(caveat), Caveat.body(caveat) | to_wire(rest)]
  end

  def to_wire([]), do: []
end
