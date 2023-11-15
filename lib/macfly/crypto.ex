defmodule Macfly.Crypto do
  @cipher :chacha20_poly1305
  @nonce_len 12
  @key_len 32
  @tag_len 16

  # @key_len * 8
  @type key() :: <<_::256>>

  # (@nonce_len + @tag_len) * 8
  @type ciphertext() :: <<_::224, _::_*8>>

  @spec seal(binary(), key()) :: binary()
  def seal(plaintext, key)

  def seal(pt, <<key::binary-size(@key_len)>>) do
    nonce = :crypto.strong_rand_bytes(@nonce_len)
    {ct, tag} = :crypto.crypto_one_time_aead(@cipher, key, nonce, pt, <<>>, true)
    <<nonce::binary, ct::binary, tag::binary>>
  end

  @spec unseal(ciphertext(), key()) :: {:ok, binary()} | {:error, any()}
  def unseal(ciphertext, key)

  def unseal(<<nonce::binary-size(@nonce_len), ct_tag::binary>>, <<key::binary-size(@key_len)>>)
      when byte_size(ct_tag) >= @tag_len do
    ct_len = byte_size(ct_tag) - @tag_len
    <<ct::binary-size(ct_len), tag::binary>> = ct_tag

    with <<pt::binary>> <- :crypto.crypto_one_time_aead(@cipher, key, nonce, ct, <<>>, tag, false) do
      {:ok, pt}
    else
      :error -> {:error, "bad key or tag"}
    end
  end

  def unseal(_, _), do: {:error, "bad key or ct len"}

  @spec sign(binary(), binary()) :: binary()
  def sign(msg, key), do: :crypto.mac(:hmac, :sha256, key, msg)

  @spec rand(integer()) :: binary()
  def rand(n) when is_integer(n), do: :crypto.strong_rand_bytes(n)
end
