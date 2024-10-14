defmodule Macfly.Action do
  alias __MODULE__

  defstruct read: false, write: false, create: false, delete: false, control: false

  @type t() :: %Action{
          read: boolean(),
          write: boolean(),
          create: boolean(),
          delete: boolean(),
          control: boolean()
        }

  @none 0b00000
  @all 0b11111

  def none(%Action{} \\ %Action{}),
    do: %Action{read: false, write: false, create: false, delete: false, control: false}

  def all(%Action{} \\ %Action{}),
    do: %Action{read: true, write: true, create: true, delete: true, control: true}

  def read(%Action{} = a \\ %Action{}), do: %{a | read: true}
  def write(%Action{} = a \\ %Action{}), do: %{a | write: true}
  def create(%Action{} = a \\ %Action{}), do: %{a | create: true}
  def delete(%Action{} = a \\ %Action{}), do: %{a | delete: true}
  def control(%Action{} = a \\ %Action{}), do: %{a | control: true}

  def from_human(human) when is_binary(human), do: from_human(human, human, none())

  def from_human(original, human, acc) do
    case human do
      "r" <> rest -> from_human(original, rest, read(acc))
      "w" <> rest -> from_human(original, rest, write(acc))
      "c" <> rest -> from_human(original, rest, create(acc))
      "d" <> rest -> from_human(original, rest, delete(acc))
      "C" <> rest -> from_human(original, rest, control(acc))
      "" -> acc
      <<perm::utf8, _rest>> -> raise "unknown permission: #{perm} in #{original}"
    end
  end

  def to_human(%Action{} = action) do
    Enum.reduce(
      [{:control, "C"}, {:delete, "d"}, {:create, "c"}, {:write, "w"}, {:read, "r"}],
      "",
      fn {key, mask}, acc ->
        if get_in(action, [Access.key(key, false)]), do: mask <> acc, else: acc
      end
    )
  end

  def from_wire(i) when is_integer(i) and i in @none..@all do
    <<control::1, delete::1, create::1, write::1, read::1>> = <<i::5>>

    {:ok,
     %Action{
       read: read == 1,
       write: write == 1,
       create: create == 1,
       delete: delete == 1,
       control: control == 1
     }}
  end

  def from_wire(_), do: {:error, "bad action set format"}

  def to_wire(%Action{
        read: read,
        write: write,
        create: create,
        delete: delete,
        control: control
      }) do
    <<i::5>> = <<
      if(control, do: 1, else: 0)::1,
      if(delete, do: 1, else: 0)::1,
      if(create, do: 1, else: 0)::1,
      if(write, do: 1, else: 0)::1,
      if(read, do: 1, else: 0)::1
    >>

    i
  end

  defimpl Jason.Encoder, for: Action do
    def encode(%Action{} = action, opts) do
      Jason.Encode.string(Macfly.Action.to_human(action), opts)
    end
  end

  defimpl Msgpax.Packer, for: Action do
    def pack(%Action{} = action) do
      Macfly.Action.to_wire(action)
    end
  end
end
