defprotocol Macfly.Caveat do
  @spec name(t) :: String.t()
  def name(v)

  @spec type(t) :: integer()
  def type(v)

  @spec body(t) :: any()
  def body(v)

  @spec from_body(t, any(), Macfly.Options.t()) :: {:ok, t()} | {:error, String.t()}
  def from_body(v, body, o)
end

defmodule Macfly.Caveat.JSON do
  defmacro defimpl_jason_encoder(module_name) do
    quote do
      defimpl Jason.Encoder, for: unquote(module_name) do
        def encode(value, opts) do
          Jason.Encode.map(
            %{
              type: Macfly.Caveat.name(value),
              body: Map.drop(value, [:__struct__])
            },
            opts
          )
        end
      end
    end
  end
end

defmodule Macfly.Caveat.Organization do
  alias __MODULE__
  alias Macfly.Action

  @enforce_keys [:id, :permission]
  defstruct [:id, :permission]
  @type t() :: %Organization{id: integer(), permission: Action.t()}

  defimpl Macfly.Caveat do
    def name(_), do: "Organization"
    def type(_), do: 0

    def body(%Organization{id: id, permission: p}), do: [id, Action.to_wire(p)]

    def from_body(_, [id, p], _) when is_integer(id) do
      case Action.from_wire(p) do
        {:ok, p} -> {:ok, %Organization{id: id, permission: p}}
        {:error, _} = err -> err
      end
    end

    def from_body(_, _, _), do: {:error, "bad Organization format"}
  end

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
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
    def name(_), do: "ValidityWindow"
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

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

defmodule Macfly.Caveat.Mutations do
  alias __MODULE__

  @enforce_keys [:mutations]
  defstruct [:mutations]
  @type t() :: %Mutations{mutations: list(String.t())}

  defimpl Macfly.Caveat do
    def name(_), do: "Mutations"
    def type(_), do: 6

    def body(%Mutations{mutations: m}), do: [m]

    def from_body(_, [m], _) when is_list(m) do
      {:ok, %Mutations{mutations: m}}
    end

    def from_body(_, body, _), do: {:error, "bad Mutations format", body}
  end

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

defmodule Macfly.Caveat.ConfineUser do
  alias __MODULE__

  @enforce_keys [:id]
  defstruct [:id]
  @type t() :: %ConfineUser{id: integer()}

  defimpl Macfly.Caveat do
    def name(_), do: "ConfineUser"
    def type(_), do: 8

    def body(%ConfineUser{id: id}), do: [id]

    def from_body(_, [id], _) when is_integer(id) do
      {:ok, %ConfineUser{id: id}}
    end

    def from_body(_, _, _), do: {:error, "bad ConfineUser format"}
  end

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

defmodule Macfly.Caveat.ConfineOrganization do
  alias __MODULE__

  @enforce_keys [:id]
  defstruct [:id]
  @type t() :: %ConfineOrganization{id: integer()}

  defimpl Macfly.Caveat do
    def name(_), do: "ConfineOrganization"
    def type(_), do: 9

    def body(%ConfineOrganization{id: id}), do: [id]

    def from_body(_, [id], _) when is_integer(id) do
      {:ok, %ConfineOrganization{id: id}}
    end

    def from_body(_, _, _), do: {:error, "bad ConfineOrganization format"}
  end

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

defmodule Macfly.Caveat.ThirdParty do
  defmodule Ticket do
    alias __MODULE__
    alias Macfly.Crypto

    @enforce_keys [:discharge_key, :caveats]
    defstruct [:discharge_key, :caveats]
    @type t() :: %Ticket{discharge_key: binary(), caveats: list(Macfly.Caveat.t())}

    @spec seal(Ticket.t(), Crypto.key()) :: binary()
    def seal(%Ticket{discharge_key: d, caveats: c}, tp_key) do
      [Msgpax.Bin.new(d), Macfly.CaveatSet.to_wire(c)]
      |> Msgpax.pack!(iodata: false)
      |> Crypto.seal(tp_key)
    end

    @spec recover(Crypto.ciphertext(), Crypto.key(), Macfly.Options.t()) ::
            {:ok, Ticket.t()} | {:error, any()}
    def recover(ciphertext, key, options \\ Macfly.default_options()) do
      with {:ok, pt} <- Crypto.unseal(ciphertext, key),
           {:ok, [%Msgpax.Bin{data: discharge_key}, wirecavs]} <- Msgpax.unpack(pt, binary: true),
           {:ok, caveats} <- Macfly.CaveatSet.from_wire(wirecavs, options) do
        {:ok, %Ticket{discharge_key: discharge_key, caveats: caveats}}
      else
        {:error, e} -> {:error, e}
        _ -> {:error, "bad Ticket format"}
      end
    end

    @spec discharge_macaroon(Crypto.ciphertext(), Crypto.key(), String.t()) ::
            {:ok, Macfly.Macaroon.t()} | {:error, any()}
    def discharge_macaroon(ciphertext, tp_key, location) do
      with {:ok, %Ticket{discharge_key: k}} <- Ticket.recover(ciphertext, tp_key) do
        {:ok, Macfly.Macaroon.new(k, ciphertext, location)}
      end
    end
  end

  alias __MODULE__
  alias Macfly.Crypto

  @enforce_keys [:location, :verifier_key, :ticket]
  defstruct [:location, :verifier_key, :ticket]
  @type t() :: %ThirdParty{location: String.t(), verifier_key: binary(), ticket: binary()}

  @spec build(String.t(), Crypto.key(), Crypto.key(), list(Macfly.Caveat.t())) :: ThirdParty.t()
  def build(location, tail, tp_key, caveats \\ []) do
    rn = Crypto.rand(32)

    ticket =
      %Ticket{discharge_key: rn, caveats: caveats}
      |> Ticket.seal(tp_key)

    %ThirdParty{
      location: location,
      verifier_key: Crypto.seal(rn, tail),
      ticket: ticket
    }
  end

  @spec recover_ticket(ThirdParty.t() | binary(), Crypto.key(), Macfly.Options.t()) ::
          {:ok, Ticket.t()} | {:error, any()}
  def recover_ticket(%ThirdParty{ticket: ct}, tp_key, options \\ Macfly.default_options()),
    do: Ticket.recover(ct, tp_key, options)

  defimpl Macfly.Caveat do
    def name(_), do: "3P"
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

  defimpl Jason.Encoder, for: __MODULE__ do
    def encode(
          %ThirdParty{location: location, verifier_key: verifier_key, ticket: ticket} = value,
          opts
        ) do
      Jason.Encode.map(
        %{
          type: Macfly.Caveat.name(value),
          body: %{
            "Location" => location,
            "VerifierKey" => verifier_key,
            "Ticket" => ticket
          }
        },
        opts
      )
    end
  end
end

defmodule Macfly.Caveat.BindToParentToken do
  alias __MODULE__

  @enforce_keys [:binding_id]
  defstruct [:binding_id]
  @type t() :: %BindToParentToken{binding_id: binary()}

  defimpl Macfly.Caveat do
    def name(_), do: "BindToParentToken"
    def type(_), do: 12

    def body(%BindToParentToken{binding_id: binding_id}) do
      Msgpax.Bin.new(binding_id)
    end

    def from_body(_, %Msgpax.Bin{data: binding_id}, _) do
      {:ok, %BindToParentToken{binding_id: binding_id}}
    end

    def from_body(_, _, _), do: {:error, "bad BindToParentToken format"}
  end

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

defmodule Macfly.Caveat.IfPresent do
  alias __MODULE__
  alias Macfly.CaveatSet

  @enforce_keys [:ifs, :else]
  defstruct [:ifs, :else]
  @type t() :: %IfPresent{ifs: list(Macfly.Caveat.t()), else: integer()}

  defimpl Macfly.Caveat do
    def name(_), do: "IfPresent"
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

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

defmodule Macfly.Caveat.ConfineGoogleHD do
  alias __MODULE__

  @enforce_keys [:hd]
  defstruct [:hd]
  @type t() :: %ConfineGoogleHD{hd: String.t()}

  defimpl Macfly.Caveat do
    def name(_), do: "ConfineGoogleHD"
    def type(_), do: 19

    def body(%ConfineGoogleHD{hd: hd}), do: hd

    def from_body(_, hd, _) when is_binary(hd) do
      {:ok, %ConfineGoogleHD{hd: hd}}
    end

    def from_body(_, _, _), do: {:error, "bad ConfineGoogleHD format"}
  end

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

defmodule Macfly.Caveat.ConfineGitHubOrg do
  alias __MODULE__

  @enforce_keys [:id]
  defstruct [:id]
  @type t() :: %ConfineGitHubOrg{id: integer()}

  defimpl Macfly.Caveat do
    def name(_), do: "ConfineGitHubOrg"
    def type(_), do: 20

    def body(%ConfineGitHubOrg{id: id}), do: id

    def from_body(_, id, _) when is_integer(id) do
      {:ok, %ConfineGitHubOrg{id: id}}
    end

    def from_body(_, _, _), do: {:error, "bad ConfineGitHubOrg format"}
  end

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

defmodule Macfly.Caveat.MaxValidity do
  alias __MODULE__

  @enforce_keys [:seconds]
  defstruct [:seconds]
  @type t() :: %MaxValidity{seconds: integer()}

  defimpl Macfly.Caveat do
    def name(_), do: "MaxValidity"
    def type(_), do: 21

    def body(%MaxValidity{seconds: seconds}), do: seconds

    def from_body(_, seconds, _) when is_integer(seconds) do
      {:ok, %MaxValidity{seconds: seconds}}
    end

    def from_body(_, _, _), do: {:error, "bad MaxValidity format"}
  end

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

defmodule Macfly.Caveat.IsMember do
  alias __MODULE__

  defstruct []
  @type t() :: %IsMember{}

  defimpl Macfly.Caveat do
    def name(_), do: "IsMember"
    def type(_), do: 22

    def body(%IsMember{}), do: []

    def from_body(_, [], _) do
      {:ok, %IsMember{}}
    end

    def from_body(_, _, _), do: {:error, "bad IsMember format"}
  end

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

# NoAdminFeatures was renamed to IsMember
defmodule Macfly.Caveat.NoAdminFeatures do
  alias __MODULE__

  defstruct []
  @type t() :: %NoAdminFeatures{}

  defimpl Macfly.Caveat do
    def name(_), do: "IsMember"
    def type(_), do: 22

    def body(%NoAdminFeatures{}), do: []

    def from_body(_, [], _) do
      {:ok, %Macfly.Caveat.IsMember{}}
    end

    def from_body(_, _, _), do: {:error, "bad IsMember format"}
  end

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

defmodule Macfly.Caveat.FlyioUserID do
  alias __MODULE__

  @enforce_keys [:id]
  defstruct [:id]
  @type t() :: %FlyioUserID{id: integer()}

  defimpl Macfly.Caveat do
    def name(_), do: "FlyioUserID"
    def type(_), do: 23

    def body(%FlyioUserID{id: id}), do: id

    def from_body(_, id, _) when is_integer(id) do
      {:ok, %FlyioUserID{id: id}}
    end

    def from_body(_, _, _), do: {:error, "bad FlyioUserID format"}
  end

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

defmodule Macfly.Caveat.GitHubUserID do
  alias __MODULE__

  @enforce_keys [:id]
  defstruct [:id]
  @type t() :: %GitHubUserID{id: integer()}

  defimpl Macfly.Caveat do
    def name(_), do: "GitHubUserID"
    def type(_), do: 24

    def body(%GitHubUserID{id: id}), do: id

    def from_body(_, id, _) when is_integer(id) do
      {:ok, %GitHubUserID{id: id}}
    end

    def from_body(_, _, _), do: {:error, "bad GitHubUserID format"}
  end

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

defmodule Macfly.Caveat.GoogleUserID do
  alias __MODULE__

  @enforce_keys [:id]
  defstruct [:id]
  @type t() :: %GoogleUserID{id: integer()}

  defimpl Macfly.Caveat do
    def name(_), do: "GoogleUserID"
    def type(_), do: 25

    def body(%GoogleUserID{id: iid}) do
      n_bytes = trunc(Float.ceil(:math.log(iid) / :math.log(256)))
      Msgpax.Bin.new(<<iid::size(n_bytes)-unit(8)>>)
    end

    def from_body(_, %Msgpax.Bin{data: bid}, _) when is_binary(bid) and byte_size(bid) <= 255 do
      <<iid::size(byte_size(bid))-unit(8)>> = bid
      {:ok, %GoogleUserID{id: iid}}
    end

    def from_body(_, body, _), do: {:error, "bad GoogleUserID format #{inspect(body)}"}
  end

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

defmodule Macfly.Caveat.FlySrc do
  alias __MODULE__

  @enforce_keys [:organization, :app, :instance]
  defstruct [:organization, :app, :instance]
  @type t() :: %FlySrc{organization: String.t(), app: String.t(), instance: String.t()}

  defimpl Macfly.Caveat do
    def name(_), do: "FlySrc"
    def type(_), do: 31

    def body(%FlySrc{organization: org, app: app, instance: inst}) do
      [org, app, inst]
    end

    def from_body(_, [org, app, inst], _)
        when is_binary(org) and is_binary(app) and is_binary(inst) do
      {:ok, %FlySrc{organization: org, app: app, instance: inst}}
    end

    def from_body(_, _, _), do: {:error, "bad FlySrc format"}
  end

  require Macfly.Caveat.JSON
  Macfly.Caveat.JSON.defimpl_jason_encoder(__MODULE__)
end

defmodule Macfly.Caveat.UnrecognizedCaveat do
  alias __MODULE__

  @enforce_keys [:type, :body]
  defstruct [:type, :body]
  @type t() :: %UnrecognizedCaveat{type: integer(), body: any()}

  defimpl Macfly.Caveat do
    def name(_), do: "Unregistered"
    def type(%UnrecognizedCaveat{type: type}), do: type
    def body(%UnrecognizedCaveat{body: body}), do: body

    def from_body(%UnrecognizedCaveat{type: type}, body, _) do
      {:ok, %UnrecognizedCaveat{type: type, body: body}}
    end
  end

  defimpl Jason.Encoder, for: __MODULE__ do
    def encode(%UnrecognizedCaveat{} = value, opts) do
      Jason.Encode.map(
        %{
          type: Macfly.Caveat.name(value),
          body: value.body
        },
        opts
      )
    end
  end
end

defmodule Macfly.Caveats do
  require Macfly.ResourceSet

  Macfly.ResourceSet.define_resource_set_caveat_module(Apps, :apps, 3)

  Macfly.ResourceSet.define_resource_set_caveat_module(
    FeatureSet,
    :features,
    5,
    ~w(wg domain site builder addon checks membership billing "litefs-cloud" deletion document_signing authentication)a
  )
end
