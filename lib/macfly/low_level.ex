defmodule Macfly.LowLevel do
  def caveats_to_wire([type, body | rest]) when is_integer(type),
    do: [type, body | caveats_to_wire(rest)]

  def caveats_to_wire([caveat | rest]),
    do: [Macfly.Caveat.type(caveat), Macfly.Caveat.body(caveat) | caveats_to_wire(rest)]

  def caveats_to_wire([]), do: []

  @doc """
  Verifies the signature without care for the semantics of the token. Notably,
  it ignores the distinction between attestations and caveats, proofs and
  macaroons, 3p caveats and discharges, etc...
  """
  def verify_tail(key, [nonce, location, wirecavs, %Msgpax.Bin{data: tail}]) do
    with {:ok, [_nonce, _location, _wirecavs, %Msgpax.Bin{data: computed_tail}]} <-
           new(key, nonce, location, wirecavs) do
      if(:crypto.hash_equals(tail, computed_tail), do: :ok, else: :error)
    end
  end

  def new(key, [_kid, _rnd, _is_proof] = nonce, location, wirecavs \\ []) do
    with {:ok, packed} <- Msgpax.pack(nonce),
         macaroon <- [nonce, location, [], sign(key, packed)] do
      attenuate_token(macaroon, wirecavs)
    end
  end

  def new_nonce(kid, rnd \\ :crypto.strong_rand_bytes(16), is_proof \\ false),
    do: [Msgpax.Bin.new(kid), Msgpax.Bin.new(rnd), is_proof]

  def attenuate_tokens(target_location, [[_, location | _] = token | rest], wirecavs)
      when is_nil(target_location) or target_location == location do
    with {:ok, attenuated} <- attenuate_token(token, wirecavs),
         {:ok, rest_attenuated} <- attenuate_tokens(target_location, rest, wirecavs) do
      {:ok, [attenuated | rest_attenuated]}
    end
  end

  def attenuate_tokens(target_location, [token | rest], wirecavs) do
    with {:ok, rest_attenuated} <- attenuate_tokens(target_location, rest, wirecavs) do
      {:ok, [token | rest_attenuated]}
    end
  end

  def attenuate_tokens(_, [], _), do: {:ok, []}

  def attenuate_token([[_kid, _rnd, _proof] = nonce, location, existing_wirecavs, tail], [
        typ,
        body | rest
      ]) do
    case Msgpax.pack([typ, body]) do
      {:ok, packed} ->
        attenuate_token(
          [nonce, location, existing_wirecavs ++ [typ, body], sign(tail, packed)],
          rest
        )

      error ->
        error
    end
  end

  def attenuate_token([[_kid, _rnd, _proof], _location, _wirecavs, _tail] = macaroon, []),
    do: {:ok, macaroon}

  def attenuate_token(_a, _b), do: {:error, "invalid macaroon structure"}

  def sign(%Msgpax.Bin{data: key}, msg), do: Msgpax.Bin.new(:crypto.mac(:hmac, :sha256, key, msg))
  def sign(<<key::binary>>, msg), do: Msgpax.Bin.new(:crypto.mac(:hmac, :sha256, key, msg))

  def encode_tokens([macaroon | rest]) do
    with {:ok, packed} <- Msgpax.pack(macaroon, iodata: false),
         encoded <- Base.encode64(packed),
         prefixed <- "fm2_" <> encoded do
      case encode_tokens(rest) do
        {:ok, ""} -> {:ok, prefixed}
        {:ok, rest_encoded} -> {:ok, "#{prefixed},#{rest_encoded}"}
        error -> error
      end
    end
  end

  def encode_tokens([]), do: {:ok, ""}

  def parse_tokens([tok | rest]) do
    with {:ok, body} <- strip_prefix(tok),
         {:ok, decoded} <- Base.decode64(body),
         {:ok, unpacked} <- Msgpax.unpack(decoded, binary: true),
         {:ok, prest} <- parse_tokens(rest) do
      {:ok, [unpacked | prest]}
    else
      :error -> {:error, "bad base64 encoding"}
      error -> error
    end
  end

  def parse_tokens([]), do: {:ok, []}

  def parse_tokens(<<header::binary>>) do
    strip_authorization_scheme(header)
    |> String.split(",")
    |> parse_tokens()
  end

  defp strip_prefix(<<"fm2_", body::binary>>), do: {:ok, body}
  defp strip_prefix(<<"fm1a_", body::binary>>), do: {:ok, body}
  defp strip_prefix(<<"fm1r_", body::binary>>), do: {:ok, body}
  defp strip_prefix(_), do: {:error, "unrecognized token format"}

  defp strip_authorization_scheme(<<"Bearer ", hdr::binary>>), do: strip_authorization_scheme(hdr)
  defp strip_authorization_scheme(<<"FlyV1 ", hdr::binary>>), do: strip_authorization_scheme(hdr)
  defp strip_authorization_scheme(<<hdr::binary>>), do: hdr
end
