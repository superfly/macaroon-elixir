defmodule Macfly.Options do
  alias __MODULE__
  alias Macfly.Caveat

  @caveat_modules [
    Caveat.ConfineUser,
    Caveat.ConfineOrganization,
    Caveat.ValidityWindow,
    Caveat.ThirdParty,
    Caveat.BindToParentToken,
    Caveat.IfPresent,
    Caveat.ConfineGoogleHD,
    Caveat.ConfineGitHubOrg
  ]

  @caveat_types for c <- @caveat_modules,
                    into: %{},
                    do: {Caveat.type(c.__struct__()), c.__struct__()}

  defstruct location: "https://api.fly.io/v1",
            caveat_types: @caveat_types

  @type t() :: %Options{location: String.t(), caveat_types: %{integer() => Caveat.t()}}

  def with_caveats(o \\ %Options{}, caveats)

  def with_caveats(%Options{} = o, []), do: o

  def with_caveats(%Options{} = o, [caveat | rest]) do
    o.caveat_types
    |> Map.put(Caveat.type(caveat), caveat)
    |> then(&%Options{o | caveat_types: &1})
    |> with_caveats(rest)
  end
end
