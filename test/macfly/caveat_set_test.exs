defmodule Macfly.CaveatSetTest do
  use ExUnit.Case

  alias Macfly.CaveatSet

  @vectors Jason.decode!(File.read!("test/vectors.json"))

  for cav <- [
        Macfly.Caveat.ConfineUser,
        Macfly.Caveat.ConfineOrganization,
        Macfly.Caveat.BindToParentToken,
        Macfly.Caveat.ConfineGoogleHD,
        Macfly.Caveat.ConfineGitHubOrg,
        Macfly.Caveat.FlySrc
      ] do
    name = to_string(cav) |> String.split(".") |> List.last()

    test "round trip #{name}" do
      %{"caveats" => %{unquote(name) => b64}} = @vectors
      mpack = Base.decode64!(b64)
      {:ok, [decoded]} = CaveatSet.decode(mpack)
      assert decoded.__struct__ == unquote(cav)
      assert mpack == CaveatSet.encode([decoded])
    end
  end
end
