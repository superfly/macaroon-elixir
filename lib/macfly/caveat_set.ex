defmodule Macfly.CaveatSet do
  alias Macfly.Options
  alias Macfly.Caveat

  def from_wire([type, body | rest], %Options{} = o) when is_integer(type) do
    with {:ok, rest} <- from_wire(rest, o),
         {:ok, caveat} <- Options.build_caveat(o, type, body) do
      {:ok, [caveat | rest]}
    else
      error -> error
    end
  end

  def from_wire([], %Options{}), do: {:ok, []}
  def from_wire([_], %Options{}), do: {:error, "bad caveat set format"}

  def to_wire([caveat | rest]) do
    [Caveat.type(caveat), Caveat.body(caveat) | to_wire(rest)]
  end

  def to_wire([]), do: []
end
