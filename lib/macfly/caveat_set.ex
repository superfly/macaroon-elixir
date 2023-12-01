defmodule Macfly.CaveatSet do
  alias Macfly.Options
  alias Macfly.Caveat

  @doc """
  Decode a message pack encoded set of caveats.
  """
  @spec decode(binary(), Macfly.Options.t()) :: {:ok, [Caveat.t()]} | {:error, any()}
  def decode(<<packed::binary>>, %Options{} = o \\  %Options{}) do
    with {:ok, raw} <- Msgpax.unpack(packed, binary: true) do
      from_wire(raw, o)
    else
      error -> error
    end
  end

  def from_wire(wire_caveats, options \\  %Options{})

  def from_wire([type, body | rest], %Options{} = o) when is_integer(type) do
    with {:ok, rest} <- from_wire(rest, o),
         {:ok, caveat} <- build_caveat(o, type, body) do
      {:ok, [caveat | rest]}
    else
      error -> error
    end
  end

  def from_wire([], %Options{}), do: {:ok, []}
  def from_wire([_], %Options{}), do: {:error, "bad caveat set format"}

  def to_wire([caveat | rest]) do
    [
      Caveat.type(caveat),
      Caveat.body(caveat) |> Macfly.MapFix.traverse()
      | to_wire(rest)
    ]
  end

  def to_wire([]), do: []

  def build_caveat(%Options{} = o \\ %Options{}, type, body) do
    case o.caveat_types do
      %{^type => struct} -> Caveat.from_body(struct, body, o)
      _ -> {:ok, %Caveat.UnrecognizedCaveat{type: type, body: body}}
    end
  end
end
