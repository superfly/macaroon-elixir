defprotocol Macfly.Caveat do
  @spec type(t) :: integer()
  def type(v)

  @spec body(t) :: any()
  def body(v)

  @spec from_body(t, any(), Macfly.CaveatTypes.t()) :: {:ok, t} | {:error, String.t()}
  def from_body(v, body, t)
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

    def from_body(_, [not_before, not_after], _)
        when is_integer(not_before) and is_integer(not_after) do
      {:ok, %ValidityWindow{not_before: not_before, not_after: not_after}}
    end

    def from_body(_, _, _), do: {:error, "bad ValidityWindow format"}
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

    def from_body(_, [location, verifier_key, ticket], _)
        when is_binary(location) and is_binary(verifier_key) and is_binary(ticket) do
      {:ok, %ThirdParty{location: location, verifier_key: verifier_key, ticket: ticket}}
    end

    def from_body(_, _, _), do: {:error, "bad ThirdParty format"}
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

    def from_body(_, binding_id, _) when is_binary(binding_id) do
      {:ok, %BindToParentToken{binding_id: binding_id}}
    end

    def from_body(_, _, _), do: {:error, "bad BindToParentToken format"}
  end
end

defmodule Macfly.Caveat.IfPresent do
  alias __MODULE__
  alias Macfly.CaveatSet

  defstruct [:ifs, :else]

  defimpl Macfly.Caveat do
    def type(_), do: 13

    def body(%IfPresent{ifs: ifs, else: els}) do
      [CaveatSet.to_wire(ifs), els]
    end

    def from_body(_, [ifs, els], t) do
      case CaveatSet.from_wire(ifs, t) do
        {:ok, ifs} -> {:ok, %IfPresent{ifs: ifs, else: els}}
      end
    end
  end
end

defmodule Macfly.Caveat.UnrecognizedCaveat do
  alias __MODULE__

  defstruct [:type, :body]

  defimpl Macfly.Caveat do
    def type(%UnrecognizedCaveat{type: type}), do: type
    def body(%UnrecognizedCaveat{body: body}), do: body

    def from_body(%UnrecognizedCaveat{type: type}, body, _) do
      %UnrecognizedCaveat{type: type, body: body}
    end
  end
end
