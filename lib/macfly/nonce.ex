defmodule Macfly.Nonce do
  alias __MODULE__

  defstruct [:kid, :rnd, :is_proof]

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
end
