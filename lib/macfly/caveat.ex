defprotocol Macfly.Caveat do
  @spec type(t) :: integer()
  def type(v)

  @spec body(t) :: any()
  def body(v)
end

defmodule Macfly.Caveat.ValidityWindow do
  defstruct [:not_before, :not_after]

  defimpl Macfly.Caveat do
    def type(_), do: 4
    def body(v), do: [v.not_before, v.not_after]
  end
end

defmodule Macfly.Caveat.ThirdParty do
  defstruct [:location, :vid, :cid]

  defimpl Macfly.Caveat do
    def type(_), do: 11
    def body(v), do: [v.location, v.vid, v.cid]
  end
end

defmodule Macfly.Caveat.BindToParentToken do
  defstruct [:body]

  defimpl Macfly.Caveat do
    def type(_), do: 12
    def body(v), do: v.body
  end
end

defmodule Macfly.Caveat.IfPresent do
  defstruct [:ifs, :else]

  defimpl Macfly.Caveat do
    def type(_), do: 13
    def body(v), do: [Macfly.LowLevel.caveats_to_wire(v.ifs), v.else]
  end
end
