defmodule Macfly.CaveatTest do
  use ExUnit.Case

  alias Macfly.Action

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

  alias Macfly.Caveats.{
    Apps,
    FeatureSet
  }

  test "ValidityWindow", do: round_trip(%ValidityWindow{not_before: 1, not_after: 2})

  test "encode ValidityWindow" do
    assert %{"type" => 4, "body" => %{"not_before" => 1, "not_after" => 2}} =
             json_round_trip(%ValidityWindow{not_before: 1, not_after: 2})
  end

  test "ConfineUser", do: round_trip(%ConfineUser{id: 1})

  test "encode ConfineUser" do
    assert %{"type" => 8, "body" => %{"id" => 1}} = json_round_trip(%ConfineUser{id: 1})
  end

  test "ConfineOrganization", do: round_trip(%ConfineOrganization{id: 1})

  test "encode ConfineOrganization" do
    assert %{"type" => 9, "body" => %{"id" => 1}} = json_round_trip(%ConfineOrganization{id: 1})
  end

  test "ThirdParty", do: round_trip(%ThirdParty{location: "a", ticket: "b", verifier_key: "c"})

  test "encode ThirdParty" do
    assert %{"type" => 11, "body" => %{"location" => "a", "ticket" => "b", "verifier_key" => "c"}} =
             json_round_trip(%ThirdParty{location: "a", ticket: "b", verifier_key: "c"})
  end

  test "BindToParentToken", do: round_trip(%BindToParentToken{binding_id: "a"})

  test "encode BindToParentToken" do
    assert %{"type" => 12, "body" => %{"binding_id" => "a"}} =
             json_round_trip(%BindToParentToken{binding_id: "a"})
  end

  test "IfPresent", do: round_trip(%IfPresent{ifs: [%ConfineUser{id: 1}], else: 1})

  test "encode IfPresent" do
    assert %{
             "type" => 13,
             "body" => %{"else" => "r", "ifs" => [%{"type" => 8, "body" => %{"id" => 1}}]}
           } =
             json_round_trip(%IfPresent{ifs: [%ConfineUser{id: 1}], else: Action.read()})
  end

  test "ConfineGoogleHD", do: round_trip(%ConfineGoogleHD{hd: "a"})

  test "encode ConfineGoogleHD" do
    assert %{"type" => 19, "body" => %{"hd" => "a"}} = json_round_trip(%ConfineGoogleHD{hd: "a"})
  end

  test "ConfineGitHubOrg", do: round_trip(%ConfineGitHubOrg{id: 1})

  test "encode ConfineGitHubOrg" do
    assert %{"type" => 20, "body" => %{"id" => 1}} = json_round_trip(%ConfineGitHubOrg{id: 1})
  end

  test "UnrecognizedCaveat", do: round_trip(%UnrecognizedCaveat{type: 9999, body: 1})

  test "encode UnrecognizedCaveat" do
    assert %{"type" => 9999, "body" => 1} =
             json_round_trip(%UnrecognizedCaveat{type: 9999, body: 1})
  end

  test "Apps", do: round_trip(Apps.build!(%{"1234" => Action.read(), "5678" => Action.control()}))

  test "encode Apps" do
    assert %{
             "type" => 3,
             "body" => %{
               "apps" => %{
                 "1234" => "r",
                 "5678" => "C"
               }
             }
           } =
             json_round_trip(Apps.build!(%{"1234" => Action.read(), "5678" => Action.control()}))
  end

  test "FeatureSet",
    do: round_trip(FeatureSet.build!(%{wg: Action.read(), builder: Action.all()}))

  test "encode FeatureSet" do
    assert %{
             "type" => 5,
             "body" => %{
               "features" => %{
                 "wg" => "r",
                 "builder" => "rwcdC"
               }
             }
           } =
             json_round_trip(FeatureSet.build!(%{wg: Action.read(), builder: Action.all()}))
  end

  test "cannot build FeatureSet with invalid features" do
    assert_raise RuntimeError, "resource not allowed: :random_feature", fn ->
      FeatureSet.build!(%{random_feature: Action.read()})
    end
  end

  test "cannot decode FeatureSet with invalid features" do
    # manually construct the caveat because the build!/1 function would raise
    cav = %FeatureSet{features: %{random_feature: Action.read()}}

    assert {:error, ~s(resource not allowed: "random_feature")} =
             Macfly.Macaroon.new("foo", "bar", "baz", [cav])
             |> to_string()
             |> Macfly.Macaroon.decode()
  end

  describe "ThirdParty" do
    alias Macfly.Caveat.ThirdParty

    test "recover" do
      {:ok, data} = File.read("test/vectors.json")

      {:ok,
       %{
         "location" => location,
         "with_tps" => header,
         "tp_key" => tp_key
       }} = Jason.decode(data)

      tp_key = Base.decode64!(tp_key)

      {:ok, macs} = Macfly.decode(header, %Macfly.Options{location: location})

      %{caveats: caveats} =
        for(%{location: ^location} = m <- macs, into: [], do: m)
        |> hd

      tps = for(%ThirdParty{} = tp <- caveats, into: [], do: tp)
      assert 2 == length(tps)

      for tp <- tps do
        {:ok, _} = ThirdParty.recover_ticket(tp, tp_key)
      end
    end

    test "round trip" do
      tp_loc = "https://location"
      tp_key = :crypto.strong_rand_bytes(32)
      mac = Macfly.Macaroon.new("foo", "bar", "baz")

      cu = %Macfly.Caveat.ConfineUser{id: 123}
      mac = Macfly.Macaroon.add_third_party(mac, tp_loc, tp_key, [cu])

      (%ThirdParty{location: ^tp_loc} = tp) =
        mac.caveats
        |> hd()

      {:ok, %ThirdParty.Ticket{caveats: [cav]}} =
        tp
        |> ThirdParty.recover_ticket(tp_key)

      assert cav == cu
    end
  end

  def round_trip(cav) do
    assert {:ok, %Macfly.Macaroon{caveats: [^cav]}} =
             Macfly.Macaroon.new("foo", "bar", "baz", [cav])
             |> to_string()
             |> Macfly.Macaroon.decode()
  end

  def json_round_trip(cav) do
    with {:ok, encoded} <- Jason.encode(cav),
         {:ok, decoded} <- Jason.decode(encoded) do
      decoded
    end
  end
end
