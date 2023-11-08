defmodule Macfly.Macaroon do
  alias __MODULE__
  alias Macfly.Options
  alias Macfly.CaveatSet
  alias Macfly.Nonce

  defstruct [:nonce, :location, :caveats, :tail]

  def new(key, kid_or_nonce, location, caveats \\ [])

  def new(<<key::binary>>, <<kid::binary>>, <<location::binary>>, caveats) do
    new(key, Nonce.new(kid), location, caveats)
  end

  def new(<<key::binary>>, %Nonce{} = nonce, <<location::binary>>, caveats)
      when is_list(caveats) do
    nonce
    |> Nonce.to_wire()
    |> Msgpax.pack!()
    |> sign(key)
    |> then(
      &%Macaroon{
        nonce: nonce,
        location: location,
        caveats: [],
        tail: &1
      }
    )
  end

  def attenuate(%Macaroon{caveats: caveats, tail: tail} = m, [caveat | rest])
      when is_list(caveats) do
    [caveat]
    |> CaveatSet.to_wire()
    |> Msgpax.pack!()
    |> sign(tail)
    |> then(&%Macaroon{m | caveats: caveats ++ [caveat], tail: &1})
    |> attenuate(rest)
  end

  def attenuate(%Macaroon{} = m, []), do: m

  def decode("fm1r_" <> token, %Options{} = o), do: _decode(token, o)
  def decode("fm1a_" <> token, %Options{} = o), do: _decode(token, o)
  def decode("fm2_" <> token, %Options{} = o), do: _decode(token, o)
  def decode(_), do: {:error, "bad prefix"}

  defp _decode(token, %Options{} = o) do
    with {:ok, decoded} <- Base.decode64(token),
         {:ok, macaroon} <- Msgpax.unpack(decoded, binary: true) do
      from_wire(macaroon, o)
    else
      :error -> {:error, "bad base64 encoding"}
      error -> error
    end
  end

  def encode(%Macaroon{} = m) do
    to_wire(m)
    |> Msgpax.pack!(iodata: false)
    |> Base.encode64()
    |> then(&("fm2_" <> &1))
  end

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

  defp sign(msg, key), do: :crypto.mac(:hmac, :sha256, key, msg)
end
