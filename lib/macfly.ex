defmodule Macfly do
  alias Macfly.Macaroon
  alias Macfly.CaveatTypes

  def attenuate_tokens(target_location \\ nil, <<header::binary>>, caveats, t \\ %CaveatTypes{}) do
    maybe_attenuate = fn m ->
      if(target_location == nil || m.location == target_location) do
        Macaroon.attenuate(m, caveats)
      else
        m
      end
    end

    case decode(header, t) do
      {:ok, macaroons} ->
        {:ok,
         macaroons
         |> Enum.map(maybe_attenuate)
         |> encode()}
    end
  end

  @spec decode(String.t(), CaveatTypes.t()) :: {:ok, list(Macaroon.t())} | {:error, any()}
  def decode(header, t \\ %CaveatTypes{})
  def decode("FlyV1 " <> toks, %CaveatTypes{} = t), do: decode(toks, t)
  def decode("Bearer " <> toks, %CaveatTypes{} = t), do: decode(toks, t)

  def decode(<<tokens::binary>>, %CaveatTypes{} = t) do
    String.split(tokens, ",") |> decode_tokens(t)
  end

  defp decode_tokens([token | rest], %CaveatTypes{} = t) do
    with {:ok, macaroon} <- Macaroon.decode(token, t),
         {:ok, rest} <- decode_tokens(rest, t) do
      {:ok, [macaroon | rest]}
    else
      error -> error
    end
  end

  defp decode_tokens([], %CaveatTypes{}), do: {:ok, []}

  @spec encode(list(Macaroon.t())) :: String.t()
  def encode(macaroons) do
    macaroons =
      macaroons
      |> Enum.map(&Macaroon.encode/1)
      |> Enum.join(",")

    "FlyV1 " <> macaroons
  end
end
