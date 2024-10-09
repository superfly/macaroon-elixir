defmodule Macfly.Options do
  alias __MODULE__
  alias Macfly.Caveat

  @caveat_modules [
    Caveat.Organization,
    Caveat.Apps,
    Caveat.ConfineUser,
    Caveat.ConfineOrganization,
    Caveat.ValidityWindow,
    Caveat.ThirdParty,
    Caveat.BindToParentToken,
    Caveat.IfPresent,
    Caveat.ConfineGoogleHD,
    Caveat.ConfineGitHubOrg,
    Caveat.NoAdminFeatures,
    Caveat.FlyioUserID,
    Caveat.GitHubUserID,
    Caveat.GoogleUserID
  ]

  @caveat_types for c <- @caveat_modules,
                    into: %{},
                    do: {Caveat.type(c.__struct__()), c.__struct__()}

  defstruct location: "https://api.fly.io/v1",
            caveat_types: @caveat_types

  @type t() :: %Options{location: String.t(), caveat_types: %{integer() => Caveat.t()}}

  @spec with_caveats(Options.t(), list(module())) :: Options.t()
  def with_caveats(%Options{caveat_types: ct} = o \\ %Options{}, caveat_modules) do
    ct =
      for c <- caveat_modules,
          into: ct,
          do: {Caveat.type(c.__struct__()), c.__struct__()}

    %{o | caveat_types: ct}
  end
end
