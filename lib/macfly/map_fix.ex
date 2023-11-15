defprotocol Macfly.MapFix do
  @fallback_to_any true
  @spec traverse(t()) :: t() | Msgpax.Fragment
  def traverse(t)
end

defimpl Macfly.MapFix, for: Map do
  def traverse(t) do
    Msgpax.Fragment.new(pack(t))
  end

  # https://github.com/lexmag/msgpax/blob/e2f31aacdbd476fec4be6abbc88d51e0dfae8c9a/lib/msgpax/packer.ex#L160-L185
  def pack(map) do
    [format(map) | map |> Map.to_list() |> Enum.sort_by(& &1) |> pack_elts()]
  end

  defp pack_elts([]), do: []

  defp pack_elts([{key, value} | rest]) do
    key =
      key
      |> @protocol.traverse()
      |> Msgpax.Packer.pack()

    value =
      value
      |> @protocol.traverse()
      |> Msgpax.Packer.pack()

    [key, value | pack_elts(rest)]
  end

  defp format(map) do
    length = map_size(map)

    cond do
      length < 16 -> 0b10000000 + length
      length < 0x10000 -> <<0xDE, length::16>>
      length < 0x100000000 -> <<0xDF, length::32>>
      true -> throw({:too_big, map})
    end
  end
end

defimpl Macfly.MapFix, for: Any do
  def traverse(t) do
    if Enumerable.impl_for(t) do
      Enum.map(t, &@protocol.traverse(&1))
    else
      t
    end
  end
end
