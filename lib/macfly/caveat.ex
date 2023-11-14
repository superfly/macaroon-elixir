defprotocol Macfly.Caveat do
  @spec type(t) :: integer()
  def type(v)

  @spec body(t) :: any()
  def body(v)

  @spec from_body(t, any(), Macfly.Options.t()) :: {:ok, t} | {:error, String.t()}
  def from_body(v, body, o)
end

defmodule Macfly.Caveat.ValidityWindow do
  alias __MODULE__

  @enforce_keys [:not_before, :not_after]
  defstruct [:not_before, :not_after]
  @type t() :: %ValidityWindow{not_before: integer(), not_after: integer()}

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

defmodule Macfly.Caveat.ConfineUser do
  alias __MODULE__

  @enforce_keys [:id]
  defstruct [:id]
  @type t() :: %ConfineUser{id: integer()}

  defimpl Macfly.Caveat do
    def type(_), do: 8

    def body(%ConfineUser{id: id}), do: [id]

    def from_body(_, [id], _) when is_integer(id) do
      {:ok, %ConfineUser{id: id}}
    end

    def from_body(_, _, _), do: {:error, "bad ConfineUser format"}
  end
end

defmodule Macfly.Caveat.ConfineOrganization do
  alias __MODULE__

  @enforce_keys [:id]
  defstruct [:id]
  @type t() :: %ConfineOrganization{id: integer()}

  defimpl Macfly.Caveat do
    def type(_), do: 9

    def body(%ConfineOrganization{id: id}), do: [id]

    def from_body(_, [id], _) when is_integer(id) do
      {:ok, %ConfineOrganization{id: id}}
    end

    def from_body(_, _, _), do: {:error, "bad ConfineOrganization format"}
  end
end

defmodule Macfly.Caveat.ThirdParty do
  defmodule Ticket do
    alias __MODULE__

    @enforce_keys [:discharge_key, :caveats]
    defstruct [:discharge_key, :caveats]
    @type t() :: %Ticket{discharge_key: binary(), caveats: list(Macfly.Caveat.t())}

    def pack(%Ticket{discharge_key: d, caveats: c}) do
      Msgpax.pack!([Msgpax.Bin.new(d), Macfly.CaveatSet.to_wire(c)])
    end

    def decode(<<pt::binary>>, o) do
      with {:ok, [%Msgpax.Bin{data: discharge_key}, wirecavs]} <- Msgpax.unpack(pt, binary: true),
           {:ok, caveats} <- Macfly.CaveatSet.from_wire(wirecavs, o) do
        {:ok, %Ticket{discharge_key: discharge_key, caveats: caveats}}
      else
        {:error, e} -> {:error, e}
        _ -> {:error, "bad Ticket format"}
      end
    end
  end

  alias __MODULE__

  @enforce_keys [:location, :verifier_key, :ticket]
  defstruct [:location, :verifier_key, :ticket]
  @type t() :: %ThirdParty{location: String.t(), verifier_key: binary(), ticket: binary()}

  @cipher :chacha20_poly1305
  @nonce_len 12
  @key_len 32
  @tag_len 16

  @type key() :: <<_::256>>

  @spec build(String.t(), key(), key(), list(Macfly.Caveat.t())) :: ThirdParty.t()
  def(build(location, tail, tp_key, caveats \\ []))

  def build(
        <<location::binary>>,
        <<tail::binary-size(@key_len)>>,
        <<tp_key::binary-size(@key_len)>>,
        caveats
      ) do
    rn = :crypto.strong_rand_bytes(@key_len)

    ticket =
      %Ticket{discharge_key: rn, caveats: caveats}
      |> Ticket.pack()
      |> then(&seal(tp_key, &1))

    %ThirdParty{
      location: location,
      verifier_key: seal(tail, rn),
      ticket: ticket
    }
  end

  @spec recover_ticket(ThirdParty.t(), key(), Macfly.Options.t()) ::
          {:ok, Ticket.t()} | {:error, any()}
  def recover_ticket(third_party, tp_key, options)

  def recover_ticket(%ThirdParty{ticket: ct}, tp_key, o) do
    with {:ok, pt} <- unseal(tp_key, ct), do: Ticket.decode(pt, o)
  end

  defp seal(<<key::binary-size(@key_len)>>, pt) do
    nonce = :crypto.strong_rand_bytes(@nonce_len)
    {ct, tag} = :crypto.crypto_one_time_aead(@cipher, key, nonce, pt, <<>>, true)
    <<nonce::binary, ct::binary, tag::binary>>
  end

  defp unseal(<<key::binary-size(@key_len)>>, <<nonce::binary-size(@nonce_len), ct_tag::binary>>)
       when byte_size(ct_tag) >= @tag_len do
    ct_len = byte_size(ct_tag) - @tag_len
    <<ct::binary-size(ct_len), tag::binary>> = ct_tag

    with <<pt::binary>> <- :crypto.crypto_one_time_aead(@cipher, key, nonce, ct, <<>>, tag, false) do
      {:ok, pt}
    else
      :error -> {:error, "bad key or tag"}
    end
  end

  defp unseal(_, _), do: {:error, "bad key or ct len"}

  defimpl Macfly.Caveat do
    def type(_), do: 11

    def body(%ThirdParty{
          location: location,
          verifier_key: verifier_key,
          ticket: ticket
        }) do
      [location, Msgpax.Bin.new(verifier_key), Msgpax.Bin.new(ticket)]
    end

    def from_body(_, [location, %Msgpax.Bin{data: verifier_key}, %Msgpax.Bin{data: ticket}], _)
        when is_binary(location) do
      {:ok, %ThirdParty{location: location, verifier_key: verifier_key, ticket: ticket}}
    end

    def from_body(_, _, _), do: {:error, "bad ThirdParty format"}
  end
end

defmodule Macfly.Caveat.BindToParentToken do
  alias __MODULE__

  @enforce_keys [:binding_id]
  defstruct [:binding_id]
  @type t() :: %BindToParentToken{binding_id: binary()}

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

  @enforce_keys [:ifs, :else]
  defstruct [:ifs, :else]
  @type t() :: %IfPresent{ifs: list(Macfly.Caveat), else: integer()}

  defimpl Macfly.Caveat do
    def type(_), do: 13

    def body(%IfPresent{ifs: ifs, else: els}) do
      [CaveatSet.to_wire(ifs), els]
    end

    def from_body(_, [ifs, els], o) do
      case CaveatSet.from_wire(ifs, o) do
        {:ok, ifs} -> {:ok, %IfPresent{ifs: ifs, else: els}}
        error -> error
      end
    end
  end
end

defmodule Macfly.Caveat.ConfineGoogleHD do
  alias __MODULE__

  @enforce_keys [:hd]
  defstruct [:hd]
  @type t() :: %ConfineGoogleHD{hd: String.t()}

  defimpl Macfly.Caveat do
    def type(_), do: 19

    def body(%ConfineGoogleHD{hd: hd}), do: hd

    def from_body(_, hd, _) when is_binary(hd) do
      {:ok, %ConfineGoogleHD{hd: hd}}
    end

    def from_body(_, _, _), do: {:error, "bad ConfineGoogleHD format"}
  end
end

defmodule Macfly.Caveat.ConfineGitHubOrg do
  alias __MODULE__

  @enforce_keys [:id]
  defstruct [:id]
  @type t() :: %ConfineGitHubOrg{id: integer()}

  defimpl Macfly.Caveat do
    def type(_), do: 20

    def body(%ConfineGitHubOrg{id: id}), do: id

    def from_body(_, id, _) when is_integer(id) do
      {:ok, %ConfineGitHubOrg{id: id}}
    end

    def from_body(_, _, _), do: {:error, "bad ConfineGitHubOrg format"}
  end
end

defmodule Macfly.Caveat.UnrecognizedCaveat do
  alias __MODULE__

  @enforce_keys [:type, :body]
  defstruct [:type, :body]
  @type t() :: %UnrecognizedCaveat{type: integer(), body: any()}

  defimpl Macfly.Caveat do
    def type(%UnrecognizedCaveat{type: type}), do: type
    def body(%UnrecognizedCaveat{body: body}), do: body

    def from_body(%UnrecognizedCaveat{type: type}, body, _) do
      {:ok, %UnrecognizedCaveat{type: type, body: body}}
    end
  end
end
