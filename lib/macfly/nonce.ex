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
    kid_uuid = UUID.uuid5(@kid_namespace, kid)
    UUID.uuid5(kid_uuid, rnd)
  end
end
