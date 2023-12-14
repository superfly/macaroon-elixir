defmodule Macfly do
  alias Macfly.Macaroon
  alias Macfly.Options
  alias Macfly.Caveat
  alias Macfly.Discharge
  alias Macfly.Caveat.ThirdParty
  alias Macfly.Nonce

  @doc """
  Decode a macaroon header into a list of Macaroon structs.
  """
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

  @doc """
  Encode a list of Macaroon structs into a macaroon header.
  """
  @spec encode(list(Macaroon.t())) :: String.t()
  def encode(macaroons) do
    macaroons
    |> Enum.map(&Macaroon.encode/1)
    |> Enum.join(",")
    |> then(&("FlyV1 " <> &1))
  end

  @doc """
  Attenuate the permission tokens within the list of macaroons.
  """
  @spec attenuate(list(Macaroon.t()), list(Caveat), Options.t()) :: list(Macaroon.t())
  def attenuate(macaroons, caveats, options \\ %Options{})
  def attenuate([], _, _), do: []

  def attenuate(
        [%Macaroon{location: location} = m | rest],
        caveats,
        %Options{
          location: target_location
        } = o
      )
      when location == target_location do
    [Macaroon.attenuate(m, caveats) | attenuate(rest, caveats, o)]
  end

  def attenuate([m | rest], caveats, %Options{} = o) do
    [m | attenuate(rest, caveats, o)]
  end

  @doc """
  Get list of Discharge structs from list of macaroons for use in discharging
  third party caveats.
  """
  @spec discharges(list(Macaroon.t()), Options.t()) :: list(Discharge.t())
  def discharges(macaroons, %Options{} = o \\ %Options{}) do
    for %ThirdParty{location: l, ticket: t} <- undischarged_tp_caveats(macaroons, o) do
      Discharge.new(location: l, ticket: t)
    end
  end

  @spec undischarged_tp_caveats(list(Macaroon.t()), Options.t()) :: list({binary(), String.t()})
  defp undischarged_tp_caveats(macaroons, %Options{location: location}) do
    # Create mapping from tp ticket to either the tp caveat that it came from or
    # the discharge macaroon that discharges it. At the end, the tickets mapping
    # to a tp caveat are necessarily undischarged.
    for m <- macaroons, reduce: %{} do
      acc ->
        case m do
          %Macaroon{location: ^location} ->
            for %ThirdParty{ticket: ticket} = c <- m.caveats, reduce: acc do
              acc -> Map.put_new(acc, ticket, c)
            end

          %Macaroon{nonce: %Nonce{kid: ticket}} ->
            Map.put(acc, ticket, m)
        end
    end
    |> then(
      &for {_, %ThirdParty{} = tp} <- &1, do: tp
    )
  end

  @spec default_options() :: Options.t()
  def default_options(), do: %Options{}
end
