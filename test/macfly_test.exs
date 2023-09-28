defmodule MacflyTest do
  use ExUnit.Case
  doctest Macfly

  test "attenuate" do
    assert {:ok, data} = File.read("test/vectors.json")
    assert {:ok, %{"location" => location, "attenuation" => attenuation_vectors}} = JSON.decode(data)
    for {hdr, attenuations} <- attenuation_vectors do
      for {encoded_cavs, expected} <- attenuations do
        cavs = Msgpax.unpack!(Base.decode64!(encoded_cavs), binary: true)
        assert Macfly.attenuate(location, hdr, cavs) == {:ok, expected}
      end
    end
  end

  test "new" do
    {:ok, hdr} = Macfly.new("foo", "bar", "baz")
    {:ok, [macaroon]} = Macfly.LowLevel.parse_tokens(hdr)
    :ok = Macfly.LowLevel.verify_tail("foo", macaroon)
  end
end
