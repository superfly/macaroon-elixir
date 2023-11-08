defmodule Macfly do
  alias Macfly.Macaroon
  alias Macfly.Options

  def attenuate_tokens(<<header::binary>>, caveats, o \\ %Options{}) do
    maybe_attenuate = fn m ->
      if(m.location == o.location) do
        Macaroon.attenuate(m, caveats)
      else
        m
      end
    end

    case decode(header, o) do
      {:ok, macaroons} ->
        macaroons
        |> Enum.map(maybe_attenuate)
        |> encode()
        |> then(&{:ok, &1})

      error ->
        error
    end
  end

  @spec decode(String.t(), Options.t()) :: {:ok, list(Macaroon.t())} | {:error, any()}
  def decode(header, o \\ %Options{})
  def decode("FlyV1 " <> toks, %Options{} = o), do: decode(toks, o)
  def decode("Bearer " <> toks, %Options{} = o), do: decode(toks, o)

  def decode(<<tokens::binary>>, %Options{} = o) do
    tokens
    |> String.split(",")
    |> decode_tokens(o)
  end

  defp decode_tokens([token | rest], %Options{} = o) do
    with {:ok, macaroon} <- Macaroon.decode(token, o),
         {:ok, rest} <- decode_tokens(rest, o) do
      {:ok, [macaroon | rest]}
    else
      error -> error
    end
  end

  defp decode_tokens([], %Options{}), do: {:ok, []}

  @spec encode(list(Macaroon.t())) :: String.t()
  def encode(macaroons) do
    macaroons
    |> Enum.map(&Macaroon.encode/1)
    |> Enum.join(",")
    |> then(&("FlyV1 " <> &1))
  end
end
