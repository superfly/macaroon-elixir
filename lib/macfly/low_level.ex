defmodule Macfly.LowLevel do
  def attenuate_tokens(target_location, [[_, location | _] = token | rest], caveats) when is_nil(target_location) or target_location == location do
    with {:ok, attenuated} <- attenuate_token(token, caveats),
         {:ok, rest_attenuated} <- attenuate_tokens(target_location, rest, caveats) do
      {:ok, [attenuated | rest_attenuated]}
    else
      error -> error
    end
  end

  def attenuate_tokens(target_location, [token | rest], caveats) do
    with {:ok, rest_attenuated} <- attenuate_tokens(target_location, rest, caveats) do
      {:ok, [token | rest_attenuated]}
    else
      error -> error
    end
  end

  def attenuate_tokens(_, [], _), do: {:ok, []}

  def attenuate_token([[_kid, _rnd, _proof] = nonce, location, existing_caveats, tail], [typ, body | rest]) do
    case Msgpax.pack([typ, body]) do
    {:ok, packed} ->
      new_tail = Msgpax.Bin.new(:crypto.mac(:hmac, :sha256, tail.data, packed))
      attenuate_token([nonce, location, existing_caveats ++ [typ, body], new_tail], rest)
    error -> error
    end
  end
  def attenuate_token([[_kid, _rnd, _proof], _location, _caveats, _tail] = macaroon, []), do: {:ok, macaroon}
  def attenuate_token(_a, _b), do: {:error, "invalid macaroon structure"}

  def encode_tokens([macaroon | rest]) do
    with {:ok, packed} <- Msgpax.pack(macaroon, iodata: false),
         encoded <- Base.encode64(packed),
         prefixed <- "fm2_#{encoded}" do
      case encode_tokens(rest) do
        {:ok, ""} -> {:ok, prefixed}
        {:ok, rest_encoded} -> {:ok, "#{prefixed},#{rest_encoded}"}
        error -> error
      end
    else
      error -> error
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
  def parse_tokens(header) do
    strip_authorization_scheme(header)
      |> String.split(",")
      |> parse_tokens()
  end

  def strip_prefix(tok) do
    case String.split(tok, "_") do
      ["fm2", body] -> {:ok, body}
      ["fm1r", body] -> {:ok, body}
      ["fm1a", body] -> {:ok, body}
      [pfx, _] -> {:error, "unrecognized prefix: #{pfx}"}
      _ -> {:error, "unrecognized token format"}
    end
  end

  @doc """
  Strips any leading scheme (Bearer or FlyV1) from an Authorization header.
  """
  def strip_authorization_scheme(header) do
    String.split(header, " ")
    |> strip_authorization_scheme_part()
    |> Enum.join(" ")
  end

  defp strip_authorization_scheme_part(["Bearer" | rest]), do: strip_authorization_scheme_part(rest)
  defp strip_authorization_scheme_part(["FlyV1" | rest]), do: strip_authorization_scheme_part(rest)
  defp strip_authorization_scheme_part(rest), do: rest
end
