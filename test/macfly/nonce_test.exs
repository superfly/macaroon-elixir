defmodule Macfly.NonceTest do
  use ExUnit.Case

  alias Macfly.Nonce

  describe "uuid/1" do
    test "returns the expected deterministic UUID" do
      assert "fddc76c6-c5f3-5383-9167-490fcf9755de" ==
               Nonce.uuid(Nonce.new("kid", "rnd"))
    end

    test "returns a valid UUIDv5" do
      uuid = Nonce.uuid(Nonce.new("kid", "rnd"))

      assert uuid =~
               ~r/^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/

      assert {:ok, <<_::128>>} = uuid |> String.replace("-", "") |> Base.decode16(case: :lower)
    end
  end
end
