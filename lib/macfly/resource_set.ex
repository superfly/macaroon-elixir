defmodule Macfly.ResourceSet do
  alias __MODULE__
  alias Macfly.Action

  @enforce_keys [:resource_name, :resources]
  defstruct [:resource_name, :resources]
  @type resources() :: %{(String.t() | integer()) => Action.t()}
  @type t() :: %__MODULE__{resources: resources()}

  def from_wire(resource_name, resources) do
    result =
      Enum.reduce(resources, {:ok, %{}}, fn {app_id, encoded_action}, accum ->
        with {:ok, accum} <- accum,
             {:ok, action} <- Action.from_wire(encoded_action) do
          {:ok, Map.put(accum, app_id, action)}
        end
      end)

    case result do
      {:ok, acc} -> {:ok, %ResourceSet{resource_name: resource_name, resources: acc}}
      {:error, _} -> {:error, "failed to decode resource set"}
    end
  end

  def to_wire(%ResourceSet{resource_name: resource_name, resources: resources}) do
    Map.put(%{}, resource_name, resources)
  end
end
