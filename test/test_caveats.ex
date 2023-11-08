# test caveats from https://github.com/superfly/macaroon/blob/6fe9504e9f940955e23dc1c4f0622c12e0ffc496/internal/test-vectors/test_vectors.go#L130-L244

defmodule TestCaveats.StringCaveat do
  alias __MODULE__

  defstruct [:value]

  defimpl Macfly.Caveat do
    def type(_), do: 281_474_976_710_656

    def body(%StringCaveat{value: value}) do
      value
    end

    def from_body(_, value, _) when is_binary(value) do
      {:ok, %StringCaveat{value: value}}
    end

    def from_body(_, _, _), do: {:error, "bad StringCaveat format"}
  end
end

defmodule TestCaveats.Int64Caveat do
  alias __MODULE__

  defstruct [:value]

  defimpl Macfly.Caveat do
    def type(_), do: 281_474_976_710_657

    def body(%Int64Caveat{value: value}) do
      value
    end

    def from_body(_, value, _) when is_integer(value) do
      {:ok, %Int64Caveat{value: value}}
    end

    def from_body(_, _, _), do: {:error, "bad Int64Caveat format"}
  end
end

defmodule TestCaveats.Uint64Caveat do
  alias __MODULE__

  defstruct [:value]

  defimpl Macfly.Caveat do
    def type(_), do: 281_474_976_710_658

    def body(%Uint64Caveat{value: value}) do
      value
    end

    def from_body(_, value, _) when is_integer(value) do
      {:ok, %Uint64Caveat{value: value}}
    end

    def from_body(_, _, _), do: {:error, "bad Uint64Caveat format"}
  end
end

defmodule TestCaveats.SliceCaveat do
  alias __MODULE__

  defstruct [:value]

  defimpl Macfly.Caveat do
    def type(_), do: 281_474_976_710_659

    def body(%SliceCaveat{value: value}) do
      Msgpax.Bin.new(value)
    end

    def from_body(_, %Msgpax.Bin{data: value}, _) when is_binary(value) do
      {:ok, %SliceCaveat{value: value}}
    end

    def from_body(_, _, _), do: {:error, "bad SliceCaveat format"}
  end
end

defmodule TestCaveats.MapCaveat do
  alias __MODULE__

  defstruct [:value]

  defimpl Macfly.Caveat do
    def type(_), do: 281_474_976_710_660

    def body(%MapCaveat{value: value}) do
      value
    end

    def from_body(_, %{} = value, _) do
      {:ok, %MapCaveat{value: value}}
    end

    def from_body(_, _, _), do: {:error, "bad MapCaveat format"}
  end
end

defmodule TestCaveats.IntResourceSetCaveat do
  alias __MODULE__

  defstruct [:value]

  defimpl Macfly.Caveat do
    def type(_), do: 281_474_976_710_661

    def body(%IntResourceSetCaveat{value: value}) do
      value
    end

    def from_body(_, %{} = value, _) do
      {:ok, %IntResourceSetCaveat{value: value}}
    end

    def from_body(_, _, _), do: {:error, "bad IntResourceSetCaveat format"}
  end
end

defmodule TestCaveats.StringResourceSetCaveat do
  alias __MODULE__

  defstruct [:value]

  defimpl Macfly.Caveat do
    def type(_), do: 281_474_976_710_662

    def body(%StringResourceSetCaveat{value: value}) do
      value
    end

    def from_body(_, %{} = value, _) do
      {:ok, %StringResourceSetCaveat{value: value}}
    end

    def from_body(_, _, _), do: {:error, "bad StringResourceSetCaveat format"}
  end
end

defmodule TestCaveats.PrefixResourceSetCaveat do
  alias __MODULE__

  defstruct [:value]

  defimpl Macfly.Caveat do
    def type(_), do: 281_474_976_710_663

    def body(%PrefixResourceSetCaveat{value: value}) do
      value
    end

    def from_body(_, %{} = value, _) do
      {:ok, %PrefixResourceSetCaveat{value: value}}
    end

    def from_body(_, _, _), do: {:error, "bad PrefixResourceSetCaveat format"}
  end
end

defmodule TestCaveats.StructCaveat do
  alias __MODULE__

  defstruct [
    :stringField,
    :intField,
    :uintField,
    :sliceField,
    :mapField,
    :intResourceSetField,
    :stringResourceSetField,
    :prefixResourceSetField
  ]

  defimpl Macfly.Caveat do
    def type(_), do: 281_474_976_710_664

    def body(%StructCaveat{
          stringField: stringField,
          intField: intField,
          uintField: uintField,
          sliceField: sliceField,
          mapField: mapField,
          intResourceSetField: intResourceSetField,
          stringResourceSetField: stringResourceSetField,
          prefixResourceSetField: prefixResourceSetField
        }) do
      [
        stringField,
        intField,
        uintField,
        Msgpax.Bin.new(sliceField),
        mapField,
        intResourceSetField,
        stringResourceSetField,
        prefixResourceSetField
      ]
    end

    def from_body(
          _,
          [
            stringField,
            intField,
            uintField,
            %Msgpax.Bin{data: sliceField},
            %{} = mapField,
            %{} = intResourceSetField,
            %{} = stringResourceSetField,
            %{} = prefixResourceSetField
          ],
          _
        )
        when is_binary(stringField) and is_integer(intField) and is_integer(uintField) do
      {:ok,
       %StructCaveat{
         stringField: stringField,
         intField: intField,
         uintField: uintField,
         sliceField: sliceField,
         mapField: mapField,
         intResourceSetField: intResourceSetField,
         stringResourceSetField: stringResourceSetField,
         prefixResourceSetField: prefixResourceSetField
       }}
    end

    def from_body(_, _, _), do: {:error, "bad StructCaveat format"}
  end
end
