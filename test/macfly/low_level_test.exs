# defmodule Macfly.LowLevelTest do
#   use ExUnit.Case

#   test "caveats_to_wire" do
#     cav = %Macfly.Caveat.ValidityWindow{not_before: 100, not_after: 200}
#     assert Macfly.LowLevel.caveats_to_wire([cav, 5, 6, cav]) == [4, [100, 200], 5, 6, 4, [100, 200]]
#   end

#   test "verify_tail" do
#     assert {:ok, data} = File.read("test/vectors.json")
#     assert {:ok, %{"key" => key64, "macaroons" => macaroons}} = JSON.decode(data)
#     for {_name, hdr} <- macaroons do
#       key = Base.decode64!(key64)
#       assert {:ok, [decoded]} = Macfly.LowLevel.parse_tokens(hdr)
#       assert :ok = Macfly.LowLevel.verify_tail(key, decoded)
#       assert :error = Macfly.LowLevel.verify_tail(String.reverse(key), decoded)
#     end
#   end

#   test "encode_tokens" do
#     assert {:ok, data} = File.read("test/vectors.json")
#     assert {:ok, %{"macaroons" => macaroons}} = JSON.decode(data)
#     for {_name, hdr} <- macaroons do
#       assert {:ok, decoded} = Macfly.LowLevel.parse_tokens(hdr)
#       [nonce | _] = decoded
#       assert {:ok, reencoded} = Macfly.LowLevel.encode_tokens(decoded)
#       assert "FlyV1 #{reencoded}" == hdr
#     end
#   end

#   test "parse" do
#     assert Macfly.LowLevel.parse_tokens("Bearer fm2_kwECAw==") == {:ok, [[1,2,3]]}
#     assert Macfly.LowLevel.parse_tokens("FlyV1 fm2_kwECAw==") == {:ok, [[1,2,3]]}
#     assert Macfly.LowLevel.parse_tokens("Bearer FlyV1 fm2_kwECAw==") == {:ok, [[1,2,3]]}
#     assert Macfly.LowLevel.parse_tokens("fm2_kwECAw==,fm1a_kwECAw==,fm1r_kwECAw==") == {:ok, [[1,2,3],[1,2,3],[1,2,3]]}
#     assert {:error, _} = Macfly.LowLevel.parse_tokens("fm3_kwECAw==")
#     assert {:error, _} = Macfly.LowLevel.parse_tokens("fm2_!oh!no!")
#     assert {:error, _} = Macfly.LowLevel.parse_tokens("Bogus fm2_kwECAw==")
#   end
# end
