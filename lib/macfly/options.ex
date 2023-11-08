defmodule Macfly.Options do
  alias __MODULE__
  alias Macfly.Caveat

  defstruct location: "https://api.fly.io/v1",
            caveat_types: %{
              Caveat.type(%Caveat.ConfineUser{}) => %Caveat.ConfineUser{},
              Caveat.type(%Caveat.ConfineOrganization{}) => %Caveat.ConfineOrganization{},
              Caveat.type(%Caveat.ValidityWindow{}) => %Caveat.ValidityWindow{},
              Caveat.type(%Caveat.ThirdParty{}) => %Caveat.ThirdParty{},
              Caveat.type(%Caveat.BindToParentToken{}) => %Caveat.BindToParentToken{},
              Caveat.type(%Caveat.IfPresent{}) => %Caveat.IfPresent{},
              Caveat.type(%Caveat.ConfineGoogleHD{}) => %Caveat.ConfineGoogleHD{},
              Caveat.type(%Caveat.ConfineGitHubOrg{}) => %Caveat.ConfineGitHubOrg{}
            }

  def with_caveats(o \\ %Options{}, caveats)

  def with_caveats(%Options{} = o, []), do: o

  def with_caveats(%Options{} = o, [caveat | rest]) do
    o.caveat_types
    |> Map.put(Caveat.type(caveat), caveat)
    |> then(&%Options{o | caveat_types: &1})
    |> with_caveats(rest)
  end

  def build_caveat(%Options{} = t, type, body) do
    case t.caveat_types do
      %{^type => struct} -> Caveat.from_body(struct, body, t)
      _ -> {:ok, %Caveat.UnrecognizedCaveat{type: type, body: body}}
    end
  end
end
