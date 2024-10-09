defprotocol Macfly.Caveat do
  @spec type(t) :: integer()
  def type(v)

  @spec body(t) :: any()
  def body(v)

  @spec from_body(t, any(), Macfly.Options.t()) :: {:ok, t()} | {:error, String.t()}
  def from_body(v, body, o)
end

defmodule Macfly.Caveat.Organization do
  alias __MODULE__
  alias Macfly.Action

  @enforce_keys [:id, :permission]
  defstruct [:id, :permission]
  @type t() :: %Organization{id: integer(), permission: Action.t()}

  defimpl Macfly.Caveat do
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
end

defmodule Macfly.Caveat.Apps do
  alias Macfly.ResourceSet
  alias __MODULE__

  @enforce_keys [:resource_set]
  defstruct [:resource_set]
  @type app_id :: String.t()
  @type t() :: %__MODULE__{resource_set: ResourceSet.t(app_id())}

  @resource_name "apps"

  @doc """
  Use this method to construct an `Apps` caveat.
  This is to ensure the `resource_name` is set to `"apps"`,
  since we match on that string when decoding this caveat.
  """
  @spec build(ResourceSet.resources(app_id())) :: t()
  def build(apps),
    do: %__MODULE__{
      resource_set: %ResourceSet{resource_name: @resource_name, resources: apps}
    }

  defimpl Macfly.Caveat do
    alias Macfly.ResourceSet

    @resource_name "apps"

    def type(_), do: 3

    def body(%Apps{} = caveat),
      do: ResourceSet.to_wire(caveat)

    def from_body(_, %{@resource_name => apps}, _) do
      ResourceSet.from_wire_struct(Apps, @resource_name, apps)
    end

    def from_body(_, _, _), do: {:error, "bad Apps format"}
  end
end

defmodule Macfly.Caveat.FeatureSet do
  alias Macfly.ResourceSet
  alias __MODULE__

  @enforce_keys [:resource_set]
  defstruct [:resource_set]

  def features(), do: ~w(wg
  domain
  site
  builder
  addon
  checks
  membership
  billing
  "litefs-cloud"
  deletion
  document_signing
  authentication)a

  @type features ::
          :wg
          | :domain
          | :site
          | :builder
          | :addon
          | :checks
          | :membership
          | :billing
          | :"litefs-cloud"
          | :deletion
          | :document_signing
          | :authentication
  @type t() :: %__MODULE__{resource_set: ResourceSet.t(features())}

  @resource_name "features"

  @doc """
  Use this method to construct a `FeatureSet` caveat.
  This is to ensure the `resource_name` is set to `"features"`,
  since we match on that string when decoding this caveat.
  This method also ensures that the features provided are valid,
  raising if there are any unexpected features.
  """
  @spec build!(ResourceSet.resources(features())) :: t()
  def build!(features) do
    if Map.keys(features)
       |> Enum.any?(fn feature -> !Enum.member?(features(), feature) end) do
      raise "invalid features"
    end

    %__MODULE__{
      resource_set: %ResourceSet{resource_name: @resource_name, resources: features}
    }
  end

  defimpl Macfly.Caveat do
    alias Macfly.ResourceSet

    @resource_name "features"

    def type(_), do: 5

    def body(%FeatureSet{} = caveat),
      do: ResourceSet.to_wire(caveat)

    def from_body(_, %{@resource_name => apps}, _) do
      ResourceSet.from_wire_struct(FeatureSet, @resource_name, apps,
        allowed_resources: FeatureSet.features()
      )
    end

    def from_body(_, _, _), do: {:error, "bad FeatureSet format"}
  end
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
      Msgpax.Bin.new(binding_id)
    end

    def from_body(_, %Msgpax.Bin{data: binding_id}, _) do
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
  @type t() :: %IfPresent{ifs: list(Macfly.Caveat.t()), else: integer()}

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

defmodule Macfly.Caveat.NoAdminFeatures do
  alias __MODULE__

  defstruct []
  @type t() :: %NoAdminFeatures{}

  defimpl Macfly.Caveat do
    def type(_), do: 22

    def body(%NoAdminFeatures{}), do: []

    def from_body(_, [], _) do
      {:ok, %NoAdminFeatures{}}
    end

    def from_body(_, _, _), do: {:error, "bad NoAdminFeatures format"}
  end
end

defmodule Macfly.Caveat.FlyioUserID do
  alias __MODULE__

  @enforce_keys [:id]
  defstruct [:id]
  @type t() :: %FlyioUserID{id: integer()}

  defimpl Macfly.Caveat do
    def type(_), do: 23

    def body(%FlyioUserID{id: id}), do: id

    def from_body(_, id, _) when is_integer(id) do
      {:ok, %FlyioUserID{id: id}}
    end

    def from_body(_, _, _), do: {:error, "bad FlyioUserID format"}
  end
end

defmodule Macfly.Caveat.GitHubUserID do
  alias __MODULE__

  @enforce_keys [:id]
  defstruct [:id]
  @type t() :: %GitHubUserID{id: integer()}

  defimpl Macfly.Caveat do
    def type(_), do: 24

    def body(%GitHubUserID{id: id}), do: id

    def from_body(_, id, _) when is_integer(id) do
      {:ok, %GitHubUserID{id: id}}
    end

    def from_body(_, _, _), do: {:error, "bad GitHubUserID format"}
  end
end

defmodule Macfly.Caveat.GoogleUserID do
  alias __MODULE__

  @enforce_keys [:id]
  defstruct [:id]
  @type t() :: %GoogleUserID{id: integer()}

  defimpl Macfly.Caveat do
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
