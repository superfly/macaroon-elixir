defmodule Macfly.ResourceSet do
  alias Macfly.Action

  @enforce_keys [:resource_name, :resources]
  defstruct [:resource_name, :resources]
  # ty should be one of String.t(), integer() or atom().
  @type resources(ty) :: %{ty => Action.t()}
  @type t(ty) :: %__MODULE__{resources: resources(ty)}

  @spec from_wire(String.t(), %{any() => integer()}, allowed_resources: list()) ::
          {:ok, t(any())} | {:error, String.t()}
  def from_wire(resource_name, resources, opts \\ []) do
    allowed_resources = Keyword.get(opts, :allowed_resources, nil)

    Enum.reduce_while(resources, %{}, fn {resource, encoded_action}, accum ->
      with {:ok, action} <- Action.from_wire(encoded_action) do
        case allowed_resources do
          nil ->
            {:cont, Map.put(accum, resource, action)}

          _ ->
            # Resources can be strings, integers or atoms. As such, converting everything
            # to strings as a canonical form is valid, since to_string/1 is injective for
            # all three types.
            case Enum.find(allowed_resources, :no_match, &(to_string(resource) == to_string(&1))) do
              :no_match -> {:halt, {:error, "resource not allowed: #{inspect(resource)}"}}
              allowed -> {:cont, Map.put(accum, allowed, action)}
            end
        end
      else
        {:error, _} = err -> {:halt, err}
        _err -> {:halt, {:error, "failed to decode action"}}
      end
    end)
    |> case do
      %{} = acc -> {:ok, %__MODULE__{resource_name: resource_name, resources: acc}}
      {:error, _} = err -> err
      _ -> {:error, "failed to decode resource set"}
    end
  end

  @doc """
  Helper method to avoid boilerplate for caveats that are simple `ResourceSet` wrappers.
  """
  @spec from_wire_struct(atom(), String.t(), %{any() => integer()}) ::
          {:ok, t(any())} | {:error, String.t()}
  def from_wire_struct(struct_name, resource_name, resources, opts \\ []) do
    with {:ok, %__MODULE__{} = resource_set} <-
           from_wire(resource_name, resources, opts) do
      {:ok, struct!(struct_name, resource_set: resource_set)}
    end
  end

  @spec to_wire(t(any()) | %{resource_set: t(any())}) :: map()
  def to_wire(x)

  def to_wire(%__MODULE__{resource_name: resource_name, resources: resources}) do
    Map.put(%{}, resource_name, resources)
  end

  @doc """
  Helper method to avoid boilerplate for caveats that are simple `ResourceSet` wrappers.
  """
  def to_wire(%{resource_set: resource_set}) do
    to_wire(resource_set)
  end
end
