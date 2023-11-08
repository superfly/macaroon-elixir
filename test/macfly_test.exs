defmodule MacflyTest do
  use ExUnit.Case
  doctest Macfly

  @test_caveats [
    %TestCaveats.StringCaveat{},
    %TestCaveats.Int64Caveat{},
    %TestCaveats.Uint64Caveat{},
    %TestCaveats.SliceCaveat{},
    %TestCaveats.MapCaveat{},
    %TestCaveats.IntResourceSetCaveat{},
    %TestCaveats.StringResourceSetCaveat{},
    %TestCaveats.PrefixResourceSetCaveat{},
    %TestCaveats.StructCaveat{}
  ]

  test "attenuate_tokens" do
    t = Macfly.CaveatTypes.with_caveats(@test_caveats)

    {:ok, data} = File.read("test/vectors.json")

    {:ok, %{"location" => location, "attenuation" => baseHeaderToAttenuations}} =
      JSON.decode(data)

    for {baseHeader, attenuations} <- baseHeaderToAttenuations do
      for {b64Cav, expected} <- attenuations do
        {:ok, cavs} =
          b64Cav
          |> Base.decode64!()
          |> Msgpax.unpack!(binary: true)
          |> Macfly.CaveatSet.from_wire(t)

        {:ok, actual} = Macfly.attenuate_tokens(location, baseHeader, cavs, t)

        assert expected == actual
      end
    end
  end

  test "encode/decode" do
    {:ok, data} = File.read("test/vectors.json")
    {:ok, %{"macaroons" => headers}} = JSON.decode(data)

    for {_, header} <- headers do
      {:ok, macaroons} = Macfly.decode(header)
      assert header == Macfly.encode(macaroons)
    end
  end

  test "encode/decode with custom caveats" do
    t = Macfly.CaveatTypes.with_caveats(@test_caveats)

    {:ok, data} = File.read("test/vectors.json")
    {:ok, %{"macaroons" => headers}} = JSON.decode(data)

    for {name, header} <- headers do
      {:ok, macaroons} = Macfly.decode(header, t)

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
          assert %TestCaveats.MapCaveat{value: %{"foo" => "bar"}} == hd(hd(macaroons).caveats)

        "IntResourceSet" ->
          assert %TestCaveats.IntResourceSetCaveat{value: %{123 => 31}} ==
                   hd(hd(macaroons).caveats)

        "StringResourceSet" ->
          assert %TestCaveats.StringResourceSetCaveat{value: %{"foo" => 31}} ==
                   hd(hd(macaroons).caveats)

        "PrefixResourceSet" ->
          assert %TestCaveats.PrefixResourceSetCaveat{value: %{"foo" => 31}} ==
                   hd(hd(macaroons).caveats)

        "Struct" ->
          assert %TestCaveats.StructCaveat{
                   stringField: "foo",
                   intField: -123,
                   uintField: 123,
                   sliceField: <<1, 2, 3>>,
                   mapField: %{"foo" => "bar"},
                   intResourceSetField: %{123 => 31},
                   stringResourceSetField: %{"foo" => 31},
                   prefixResourceSetField: %{"foo" => 31}
                 } == hd(hd(macaroons).caveats)
      end

      assert header == Macfly.encode(macaroons)
    end
  end

  test "decode bad input" do
    {:error, _} = Macfly.decode("FlyV1 fm2_x")
    {:error, _} = Macfly.decode("FlyV1 FlyV1 fm2_o2Zvbw==")
  end
end
