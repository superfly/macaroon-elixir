defmodule Macfly.Macaroon do
  alias __MODULE__
  alias Macfly.{Options, CaveatSet, Nonce, Crypto}

  @enforce_keys [:nonce, :location, :caveats, :tail]
  defstruct [:nonce, :location, :caveats, :tail]

  @type t() :: %Macaroon{
          nonce: Nonce.t(),
          location: String.t(),
          caveats: list(Macfly.Caveat.t()),
          tail: binary()
        }

  @spec new(binary(), binary() | Nonce.t(), String.t(), list(Macfly.Caveat.t())) :: Macaroon.t()
  def new(key, kid_or_nonce, location, caveats \\ [])

  def new(<<key::binary>>, <<kid::binary>>, <<location::binary>>, caveats) do
    new(key, Nonce.new(kid), location, caveats)
  end

  def new(<<key::binary>>, %Nonce{} = nonce, <<location::binary>>, caveats)
      when is_list(caveats) do
    nonce
    |> Nonce.to_wire()
    |> Msgpax.pack!()
    |> Crypto.sign(key)
    |> then(
      &%Macaroon{
        nonce: nonce,
        location: location,
        caveats: [],
        tail: &1
      }
    )
    |> attenuate(caveats)
  end

  @spec attenuate(Macaroon.t(), list(Macfly.Caveat.t())) :: Macaroon.t()
  def attenuate(%Macaroon{caveats: caveats, tail: tail} = m, [caveat | rest])
      when is_list(caveats) do
    [caveat]
    |> CaveatSet.to_wire()
    |> Msgpax.pack!()
    |> Crypto.sign(tail)
    |> then(&%Macaroon{m | caveats: caveats ++ [caveat], tail: &1})
    |> attenuate(rest)
  end

  def attenuate(%Macaroon{} = m, []), do: m

  @spec add_third_party(Macaroon.t(), String.t(), <<_::256>>, list(Macfly.Caveat.t())) ::
          Macaroon.t()
  def add_third_party(m, location, tp_key, caveats \\ [])

  def add_third_party(
        %Macaroon{tail: tail} = m,
        <<location::binary>>,
        <<tp_key::binary>>,
        caveats
      ) do
    tp = Macfly.Caveat.ThirdParty.build(location, tail, tp_key, caveats)
    attenuate(m, [tp])
  end

  @spec decode(String.t(), Options.t()) :: {:ok, Macaroon.t()} | {:error, any()}
  def decode(token, options \\ %Options{})
  def decode("fm1r_" <> token, %Options{} = o), do: _decode(token, o)
  def decode("fm1a_" <> token, %Options{} = o), do: _decode(token, o)
  def decode("fm2_" <> token, %Options{} = o), do: _decode(token, o)
  def decode(_, _), do: {:error, "bad prefix"}

  defp _decode(token, o) do
    with {:ok, decoded} <- Base.decode64(token),
         {:ok, macaroon} <- Msgpax.unpack(decoded, binary: true) do
      from_wire(macaroon, o)
    else
      :error -> {:error, "bad base64 encoding"}
      error -> error
    end
  end

  @spec encode(Macaroon.t()) :: String.t()
  def encode(%Macaroon{} = m), do: to_string(m)

  def from_wire(wire_macaroon, options \\ %Options{})

  def from_wire([nonce, location, caveats, %Msgpax.Bin{data: tail}], %Options{} = o) do
    with {:ok, nonce} <- Nonce.from_wire(nonce),
         {:ok, caveats} <- CaveatSet.from_wire(caveats, o) do
      {:ok,
       %Macaroon{
         nonce: nonce,
         location: location,
         caveats: caveats,
         tail: tail
       }}
    else
      error -> error
    end
  end

  def from_wire(_, %Options{}), do: {:error, "bad macaroon format"}

  def to_wire(%Macaroon{nonce: nonce, location: location, caveats: caveats, tail: tail}) do
    [
      Nonce.to_wire(nonce),
      location,
      CaveatSet.to_wire(caveats),
      Msgpax.Bin.new(tail)
    ]
  end

  defimpl String.Chars do
    def to_string(%Macaroon{} = m) do
      Macaroon.to_wire(m)
      |> Msgpax.pack!(iodata: false)
      |> Base.encode64()
      |> then(&("fm2_" <> &1))
    end
  end
end
