defprotocol Macfly.Caveat do
  @spec type(t) :: integer()
  def type(v)

  @spec body(t) :: any()
  def body(v)

  @spec from_body(t, any()) :: t
  def from_body(v, body)
end

defmodule Macfly.Caveat.ValidityWindow do
  alias __MODULE__

  defstruct [:not_before, :not_after]

  def build(for: seconds) do
    %ValidityWindow{
      not_before: System.os_time(:second),
      not_after: System.os_time(:second) + seconds
    }
  end

  defimpl Macfly.Caveat do
    def type(_), do: 4

    def body(%ValidityWindow{not_before: not_before, not_after: not_after}) do
      [not_before, not_after]
    end

    def from_body(_, [not_before, not_after]) do
      %ValidityWindow{not_before: not_before, not_after: not_after}
    end
  end
end

defmodule Macfly.Caveat.ThirdParty do
  alias __MODULE__

  defstruct [:location, :verifier_key, :ticket]

  defimpl Macfly.Caveat do
    def type(_), do: 11

    def body(%ThirdParty{
          location: location,
          verifier_key: verifier_key,
          ticket: ticket
        }) do
      [location, verifier_key, ticket]
    end

    def from_body(_, [location, verifier_key, ticket]) do
      %ThirdParty{location: location, verifier_key: verifier_key, ticket: ticket}
    end
  end
end

defmodule Macfly.Caveat.BindToParentToken do
  alias __MODULE__

  defstruct [:binding_id]

  defimpl Macfly.Caveat do
    def type(_), do: 12

    def body(%BindToParentToken{binding_id: binding_id}) do
      binding_id
    end

    def from_body(_, binding_id) do
      %BindToParentToken{binding_id: binding_id}
    end
  end
end

defmodule Macfly.Caveat.IfPresent do
  alias __MODULE__

  defstruct [:ifs, :else]

  defimpl Macfly.Caveat do
    def type(_), do: 13

    def body(%IfPresent{ifs: ifs, else: els}) do
      [Macfly.LowLevel.caveats_to_wire(ifs), els]
    end

    def from_body(_, [wire_ifs, els]) do
      %IfPresent{ifs: wire_ifs, else: els}
    end
  end
end

defmodule Macfly.Caveat.Registry do
  alias __MODULE__

  defstruct entries: %{}

  @spec default() :: %Registry{}
  def default() do
    %Registry{}
    |> register(%Macfly.Caveat.ValidityWindow{})
    |> register(%Macfly.Caveat.ThirdParty{})
    |> register(%Macfly.Caveat.BindToParentToken{})
    |> register(%Macfly.Caveat.IfPresent{})
  end

  @spec register(%Registry{}, Macfly.Caveat.t()) :: %Registry{}
  def register(r, caveat) do
    %Registry{r | entries: Map.put(r.entries, Macfly.Caveat.type(caveat), caveat)}
  end

  @spec from_wire(list()) :: :error | {:ok, [Macfly.Caveat.t()]}
  def from_wire(wirecavs), do: from_wire(default(), wirecavs)

  @spec from_wire(%Registry{}, list()) :: :error | {:ok, [Macfly.Caveat.t()]}
  def from_wire(r, [type, body | rest]) do
    with %{^type => struct} <- r.entries,
         {:ok, restCaveats} <- from_wire(r, rest) do
      {:ok, [Macfly.Caveat.from_body(struct, body) | restCaveats]}
    else
      _ -> :error
    end
  end

  def from_wire(_, []), do: {:ok, []}
end
