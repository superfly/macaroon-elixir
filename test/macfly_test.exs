defmodule MacflyTest do
  use ExUnit.Case
  doctest Macfly

  @test_caveats [
    TestCaveats.StringCaveat,
    TestCaveats.Int64Caveat,
    TestCaveats.Uint64Caveat,
    TestCaveats.SliceCaveat,
    TestCaveats.MapCaveat,
    TestCaveats.IntResourceSetCaveat,
    TestCaveats.StringResourceSetCaveat,
    TestCaveats.PrefixResourceSetCaveat
  ]

  test "attenuate" do
    {:ok, data} = File.read("test/vectors.json")

    {:ok, %{"location" => location, "attenuation" => baseHeaderToAttenuations}} =
      Jason.decode(data)

    o = Macfly.Options.with_caveats(%Macfly.Options{location: location}, @test_caveats)

    for {baseHeader, attenuations} <- baseHeaderToAttenuations do
      for {b64Cav, expected} <- attenuations do
        {:ok, cavs} =
          b64Cav
          |> Base.decode64!()
          |> Msgpax.unpack!(binary: true)
          |> Macfly.CaveatSet.from_wire(o)

        {:ok, macaroons} = Macfly.decode(baseHeader)

        assert expected == Macfly.attenuate(macaroons, cavs, o) |> Macfly.encode()
      end
    end
  end

  test "encode/decode" do
    {:ok, data} = File.read("test/vectors.json")
    {:ok, %{"macaroons" => headers}} = Jason.decode(data)

    for {_, header} <- headers do
      {:ok, macaroons} = Macfly.decode(header)
      assert header == Macfly.encode(macaroons)
    end
  end

  test "encode/decode with custom caveats" do
    o = Macfly.Options.with_caveats(@test_caveats)

    {:ok, data} = File.read("test/vectors.json")
    {:ok, %{"macaroons" => headers}} = Jason.decode(data)

    for {name, header} <- headers do
      {:ok, macaroons} = Macfly.decode(header, o)

      case name do
        "String" ->
          assert %TestCaveats.StringCaveat{value: "foo"} == hd(hd(macaroons).caveats)

        "Int64" ->
          assert %TestCaveats.Int64Caveat{value: -123} == hd(hd(macaroons).caveats)

        "Uint64" ->
          assert %TestCaveats.Uint64Caveat{value: 123} == hd(hd(macaroons).caveats)

        "Slice" ->
          assert %TestCaveats.SliceCaveat{value: <<1, 2, 3>>} == hd(hd(macaroons).caveats)

        "Map" ->
          assert %TestCaveats.MapCaveat{value: %{"a" => "a", "b" => "b", "c" => "c"}} ==
                   hd(hd(macaroons).caveats)

        "IntResourceSet" ->
          assert %TestCaveats.IntResourceSetCaveat{value: %{1 => 31, 2 => 31, 3 => 31}} ==
                   hd(hd(macaroons).caveats)

        "StringResourceSet" ->
          assert %TestCaveats.StringResourceSetCaveat{value: %{"a" => 31, "b" => 31, "c" => 31}} ==
                   hd(hd(macaroons).caveats)

        "PrefixResourceSet" ->
          assert %TestCaveats.PrefixResourceSetCaveat{value: %{"a" => 31, "b" => 31, "c" => 31}} ==
                   hd(hd(macaroons).caveats)

        "Struct" ->
          assert %Macfly.Caveat.UnrecognizedCaveat{
                   type: 281_474_976_710_664,
                   body: [
                     "foo",
                     -123,
                     123,
                     Msgpax.Bin.new(<<1, 2, 3>>),
                     %{"a" => "a", "b" => "b", "c" => "c"},
                     %{1 => 31, 2 => 31, 3 => 31},
                     %{"a" => 31, "b" => 31, "c" => 31},
                     %{"a" => 31, "b" => 31, "c" => 31}
                   ]
                 } == hd(hd(macaroons).caveats)

        "Organization" ->
          assert %Macfly.Caveat.Organization{id: 123, permission: Macfly.Action.all()} ==
                   hd(hd(macaroons).caveats)

        "ConfineUser" ->
          assert %Macfly.Caveat.ConfineUser{id: 123} == hd(hd(macaroons).caveats)

        "ConfineOrganization" ->
          assert %Macfly.Caveat.ConfineOrganization{id: 123} == hd(hd(macaroons).caveats)

        "ConfineGoogleHD" ->
          assert %Macfly.Caveat.ConfineGoogleHD{hd: "123"} == hd(hd(macaroons).caveats)

        "ConfineGitHubOrg" ->
          assert %Macfly.Caveat.ConfineGitHubOrg{id: 123} == hd(hd(macaroons).caveats)

        "BindToParentToken" ->
          assert %Macfly.Caveat.BindToParentToken{binding_id: <<1, 2, 3>>} ==
                   hd(hd(macaroons).caveats)

        "IsMember" ->
          assert %Macfly.Caveat.IsMember{} == hd(hd(macaroons).caveats)

        "FlyioUserID" ->
          assert %Macfly.Caveat.FlyioUserID{id: 123} == hd(hd(macaroons).caveats)

        "GitHubUserID" ->
          assert %Macfly.Caveat.GitHubUserID{id: 123} == hd(hd(macaroons).caveats)

        "GoogleUserID" ->
          assert %Macfly.Caveat.GoogleUserID{id: 0xDEADBEEF_DEADBEEF_7B} ==
                   hd(hd(macaroons).caveats)

        "Mutations" ->
          assert %Macfly.Caveat.Mutations{mutations: ["foo"]} ==
                   hd(hd(macaroons).caveats)

        "FlySrc" ->
          assert %Macfly.Caveat.FlySrc{organization: "foo", app: "bar", instance: "baz"} ==
                   hd(hd(macaroons).caveats)
      end

      assert header == Macfly.encode(macaroons)
    end
  end

  test "decode bad input" do
    {:error, _} = Macfly.decode("FlyV1 fm2_x")
    {:error, _} = Macfly.decode("FlyV1 FlyV1 fm2_o2Zvbw==")
  end

  test "discharges" do
    {:ok, data} = File.read("test/vectors.json")

    {:ok, %{"location" => location, "with_tps" => header}} =
      Jason.decode(data)

    o = %Macfly.Options{location: location}
    {:ok, macaroons} = Macfly.decode(header)

    loc = URI.parse("undischarged")

    [
      %Macfly.Discharge{
        location: ^loc,
        ticket: <<_::binary>>,
        state: :init
      }
    ] = Macfly.discharges(macaroons, o)
  end
end
