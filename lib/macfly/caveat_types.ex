defmodule Macfly.CaveatTypes do
  alias __MODULE__
  alias Macfly.Caveat

  defstruct mapping: %{
              Caveat.type(%Caveat.ValidityWindow{}) => %Caveat.ValidityWindow{},
              Caveat.type(%Caveat.ThirdParty{}) => %Caveat.ThirdParty{},
              Caveat.type(%Caveat.BindToParentToken{}) => %Caveat.BindToParentToken{},
              Caveat.type(%Caveat.IfPresent{}) => %Caveat.IfPresent{}
            }

  def with_caveats(t \\ %CaveatTypes{}, caveats)

  def with_caveats(%CaveatTypes{} = t, [caveat | rest]) do
    %CaveatTypes{mapping: Map.put(t.mapping, Caveat.type(caveat), caveat)}
    |> with_caveats(rest)
  end

  def with_caveats(%CaveatTypes{} = t, []), do: t

  def build_caveat(%CaveatTypes{} = t, type, body) do
    with %{^type => struct} <- t.mapping do
      Caveat.from_body(struct, body, t)
    else
      _ -> {:ok, %Caveat.UnrecognizedCaveat{type: type, body: body}}
    end
  end
end
