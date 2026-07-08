defmodule Macfly.Nonce do
  alias __MODULE__

  @kid_namespace "968fc2c6-a94f-4988-a544-2ad72b02f222"

  @enforce_keys [:kid, :rnd, :is_proof]
  defstruct [:kid, :rnd, :is_proof]
  @type t() :: %Nonce{kid: binary(), rnd: binary(), is_proof: boolean()}

  def new(kid, rnd \\ :crypto.strong_rand_bytes(16), is_proof \\ false) do
    %Nonce{kid: kid, rnd: rnd, is_proof: is_proof}
  end

  def from_wire([%Msgpax.Bin{data: kid}, %Msgpax.Bin{data: rnd}, is_proof]) do
    {:ok, new(kid, rnd, is_proof)}
  end

  def from_wire(_), do: {:error, "bad nonce format"}

  def to_wire(%Nonce{kid: kid, rnd: rnd, is_proof: is_proof}) do
    [Msgpax.Bin.new(kid), Msgpax.Bin.new(rnd), is_proof]
  end

  def uuid(%Nonce{kid: kid, rnd: rnd}) do
    kid_uuid = uuid5(@kid_namespace, kid)
    uuid5(kid_uuid, rnd)
  end

  defp uuid5(namespace, name) when is_binary(namespace) and is_binary(name) do
    namespace
    |> uuid_to_binary()
    |> then(&:crypto.hash(:sha, &1 <> name))
    |> binary_part(0, 16)
    |> put_uuid5_bits()
    |> format_uuid()
  end

  defp uuid_to_binary(uuid) do
    uuid
    |> String.replace("-", "")
    |> Base.decode16!(case: :mixed)
  end

  defp put_uuid5_bits(<<a::binary-size(6), version, b, variant, c::binary-size(7)>>) do
    version = version |> Bitwise.band(0x0F) |> Bitwise.bor(0x50)
    variant = variant |> Bitwise.band(0x3F) |> Bitwise.bor(0x80)

    <<a::binary, version, b, variant, c::binary>>
  end

  defp format_uuid(
         <<a::binary-size(4), b::binary-size(2), c::binary-size(2), d::binary-size(2),
           e::binary-size(6)>>
       ) do
    [a, b, c, d, e]
    |> Enum.map_join("-", &Base.encode16(&1, case: :lower))
  end
end
