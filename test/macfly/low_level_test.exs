defmodule Macfly.LowLevelTest do
  use ExUnit.Case

  test "encode_tokens" do
    assert {:ok, data} = File.read("test/vectors.json")
    assert {:ok, %{"macaroons" => macaroons}} = JSON.decode(data)
    for {name, hdr} <- macaroons do
      assert {:ok, decoded} = Macfly.LowLevel.parse_tokens(hdr)
      assert {:ok, reencoded} = Macfly.LowLevel.encode_tokens(decoded)
      assert "FlyV1 #{reencoded}" == hdr
    end
  end

  test "parse" do
    assert Macfly.LowLevel.parse_tokens("FlyV1 fm2_kwECAw==") == {:ok, [[1,2,3]]}
    assert Macfly.LowLevel.parse_tokens("fm2_kwECAw==,fm1a_kwECAw==,fm1r_kwECAw==") == {:ok, [[1,2,3],[1,2,3],[1,2,3]]}
    assert {:error, _} = Macfly.LowLevel.parse_tokens("fm3_kwECAw==")
    assert {:error, _} = Macfly.LowLevel.parse_tokens("fm2_!oh!no!")
  end

  test "strip_prefix" do
    assert Macfly.LowLevel.strip_prefix("fm1a_foo") == {:ok, "foo"}
    assert Macfly.LowLevel.strip_prefix("fm1r_foo") == {:ok, "foo"}
    assert Macfly.LowLevel.strip_prefix("fm2_foo") == {:ok, "foo"}
    assert Macfly.LowLevel.strip_prefix("fmx_foo") == {:error, "unrecognized prefix: fmx"}
    assert Macfly.LowLevel.strip_prefix("bogus") == {:error, "unrecognized token format"}
  end

  test "strip_authorization_scheme" do
    assert Macfly.LowLevel.strip_authorization_scheme("Bearer FlyV1 foo bar") == "foo bar"
    assert Macfly.LowLevel.strip_authorization_scheme("foo bar") == "foo bar"
    assert Macfly.LowLevel.strip_authorization_scheme("FlyV1 foo bar") == "foo bar"
    assert Macfly.LowLevel.strip_authorization_scheme("Bearer foo bar") == "foo bar"
  end
end
