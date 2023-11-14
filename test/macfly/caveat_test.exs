defmodule Macfly.CaveatTest do
  use ExUnit.Case

  alias Macfly.Caveat.{
    ValidityWindow,
    ConfineUser,
    ConfineOrganization,
    ThirdParty,
    BindToParentToken,
    ConfineGoogleHD,
    ConfineGitHubOrg,
    UnrecognizedCaveat,
    IfPresent
  }

  test "ValidityWindow", do: round_trip(%ValidityWindow{not_before: 1, not_after: 2})
  test "ConfineUser", do: round_trip(%ConfineUser{id: 1})
  test "ConfineOrganization", do: round_trip(%ConfineOrganization{id: 1})
  test "ThirdParty", do: round_trip(%ThirdParty{location: "a", ticket: "b", verifier_key: "c"})
  test "BindToParentToken", do: round_trip(%BindToParentToken{binding_id: "a"})
  test "IfPresent", do: round_trip(%IfPresent{ifs: [%ConfineUser{id: 1}], else: 1})
  test "ConfineGoogleHD", do: round_trip(%ConfineGoogleHD{hd: "a"})
  test "ConfineGitHubOrg", do: round_trip(%ConfineGitHubOrg{id: 1})
  test "UnrecognizedCaveat", do: round_trip(%UnrecognizedCaveat{type: 9999, body: 1})

  def round_trip(cav) do
    Macfly.Macaroon.new("foo", "bar", "baz", [cav])
    |> to_string()
    |> Macfly.Macaroon.decode(%Macfly.Options{})
    |> then(fn {:ok, %Macfly.Macaroon{caveats: [decoded]}} -> decoded end)
    |> then(&assert cav == &1)
  end
end
