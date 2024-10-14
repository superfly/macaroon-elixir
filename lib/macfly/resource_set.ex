defmodule Macfly.ResourceSet do
  defmacro define_resource_set_caveat_module(
             module_name,
             resources_key,
             caveat_type,
             allowed_resources \\ :undefined
           ) do
    quote do
      defmodule unquote(module_name) do
        alias Macfly.Action
        alias __MODULE__

        @enforce_keys [unquote(resources_key)]
        defstruct [unquote(resources_key)]

        defimpl Jason.Encoder, for: unquote(module_name) do
          def encode(%unquote(module_name){unquote(resources_key) => resources} = value, opts) do
            Jason.Encode.map(
              %{
                type: Macfly.Caveat.name(value),
                body: %{unquote(resources_key) => resources}
              },
              opts
            )
          end
        end

        @type t() :: %__MODULE__{
                unquote(resources_key) => %{(String.t() | integer() | atom()) => Action.t()}
              }

        def build!(resources) do
          resources =
            case unquote(allowed_resources) do
              :undefined ->
                resources

              _ ->
                # Resources can be strings, integers or atoms. As such, converting everything
                # to strings as a canonical form is valid, since to_string/1 is injective for
                # all three types.
                Enum.reduce(resources, %{}, fn {resource, action}, accum ->
                  case Enum.find(
                         unquote(allowed_resources),
                         :no_match,
                         &(to_string(resource) == to_string(&1))
                       ) do
                    :no_match -> raise "resource not allowed: #{inspect(resource)}"
                    allowed -> Map.put(accum, allowed, action)
                  end
                end)
            end

          %__MODULE__{unquote(resources_key) => resources}
        end

        defimpl Macfly.Caveat do
          # Defining this here because we need a compile time
          # atom in order to be able to construct structs in code below.
          @parent_module unquote(module_name)

          def name(_), do: unquote(module_name) |> Module.split() |> Enum.at(-1)
          def type(_), do: unquote(caveat_type)

          def body(%@parent_module{unquote(resources_key) => resources}) do
            [resources]
          end

          def from_body(_, [%{} = resources], _) do
            Enum.reduce_while(resources, %{}, fn {resource, encoded_action}, accum ->
              with {:ok, action} <- Action.from_wire(encoded_action) do
                case unquote(allowed_resources) do
                  :undefined ->
                    {:cont, Map.put(accum, resource, action)}

                  _ ->
                    # Resources can be strings, integers or atoms. As such, converting everything
                    # to strings as a canonical form is valid, since to_string/1 is injective for
                    # all three types.
                    case Enum.find(
                           unquote(allowed_resources),
                           :no_match,
                           &(to_string(resource) == to_string(&1))
                         ) do
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
              %{} = acc ->
                {:ok, %@parent_module{unquote(resources_key) => acc}}

              {:error, _} = err ->
                err

              _ ->
                {:error, "failed to decode resource set"}
            end
          end
        end

        def from_body(t, _, _), do: {:error, "bad #{Macfly.Caveat.name(t)} format"}
      end
    end
  end
end
