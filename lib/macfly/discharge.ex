defmodule Macfly.Discharge do
  alias __MODULE__
  alias Macfly.HTTP

  @enforce_keys [:location, :ticket, :id]
  defstruct location: nil,
            ticket: nil,
            state: :init,
            auth: %{},
            id: nil

  @type t() :: %Discharge{
          location: URI.t(),
          ticket: binary() | nil,
          state: state(),
          auth: map(),
          id: binary()
        }

  @init_path "/.well-known/macfly/3p"
  @json_header ["Content-Type": "application/json"]

  @type error() ::
          {:error, :failed, HTTPoison.Error.t()}
          | {:error, integer(),
             String.t()
             | {:bad_response, term()}
             | {:bad_json, String.t(), term()}}

  @type state() ::
          :init
          | {:poll, String.t()}
          | {:user_interactive, String.t(), String.t()}
          | {:success, String.t()}
          | error()

  def new(location: location, ticket: ticket) do
    %Discharge{
      location: URI.parse(location),
      ticket: ticket,
      id: :crypto.hash(:sha256, ticket)
    }
  end

  def with_bearer_auth(%Discharge{} = d, hostname, token) do
    d
    |> Map.get(:auth, %{})
    |> Map.put(hostname, "Bearer " <> token)
    |> then(&%Discharge{d | auth: &1})
  end

  @doc """
  Attempts to perform the next step in the discharge protocol. The caller should
  check the state between calls to next(). Terminal states are :success and
  :error. For :user_interactive, the caller is responsible for redirecting the
  user to the user_url before calling next() again.
  """
  @spec next(%Discharge{state: state()}) :: %Discharge{state: state()}
  def next(%Discharge{state: {:error, _}} = d), do: d

  def next(%Discharge{state: :init} = d), do: do_init(d, append_path(d, @init_path))

  def next(%Discharge{state: {:poll, poll_url}} = d) do
    u = merge_url(d, poll_url)
    h = headers(d, u)

    u
    |> HTTP.get(h)
    |> handle_poll_response(d)
  end

  def next(%Discharge{state: {:user_interactive, _, poll_url}} = d) do
    %Discharge{d | state: {:poll, poll_url}}
    |> next()
  end

  defp do_init(%Discharge{ticket: t} = d, url) do
    h = headers(d, url, @json_header)

    t
    |> Base.encode64()
    |> then(&%{ticket: &1})
    |> JSON.encode!()
    |> then(&HTTP.post(url, &1, h))
    |> handle_init_response(d)

    # Ticket isn't needed moving forward. Remove it so Discharges can be
    # serialized more compactly.
    |> then(&%Discharge{&1 | ticket: nil})
  end

  defp handle_init_response({:error, e}, d),
    do: %Discharge{d | state: {:error, :failed, e}}

  defp handle_init_response({:ok, %HTTPoison.MaybeRedirect{status_code: s, redirect_url: r}}, d)
       when s in [307, 308] do
    do_init(d, merge_url(d, r))
  end

  defp handle_init_response({:ok, %HTTPoison.Response{status_code: status, body: body}}, d) do
    case JSON.decode(body) do
      {:ok, %{"discharge" => discharge}} ->
        %Discharge{d | state: {:success, discharge}}

      {:ok, %{"poll_url" => poll_url}} ->
        %Discharge{d | state: {:poll, poll_url}}

      {:ok, %{"user_interactive" => %{"user_url" => user_url, "poll_url" => poll_url}}} ->
        user_url = merge_url(d, user_url) |> to_string
        %Discharge{d | state: {:user_interactive, user_url, poll_url}}

      {:ok, %{"error" => error}} ->
        %Discharge{d | state: {:error, status, error}}

      {:ok, j} ->
        %Discharge{d | state: {:error, status, {:bad_response, j}}}

      {:error, error} ->
        %Discharge{d | state: {:error, status, {:bad_json, body, error}}}
    end
  end

  defp handle_poll_response({:ok, %HTTPoison.Response{status_code: 202}}, d), do: d

  defp handle_poll_response({:error, e}, d),
    do: %Discharge{d | state: {:error, :failed, e}}

  defp handle_poll_response({:ok, %HTTPoison.Response{status_code: status, body: body}}, d) do
    case JSON.decode(body) do
      {:ok, %{"discharge" => discharge}} ->
        %Discharge{d | state: {:success, discharge}}

      {:ok, %{"error" => error}} ->
        %Discharge{d | state: {:error, status, error}}

      {:ok, j} ->
        %Discharge{d | state: {:error, status, {:bad_response, j}}}

      {:error, error} ->
        %Discharge{d | state: {:error, status, {:bad_json, body, error}}}
    end
  end

  defp merge_url(%Discharge{location: l}, path), do: URI.merge(l, path)

  # not available until elixir 1.15.0
  # https://github.com/elixir-lang/elixir/blob/53f45a93b62842e202458c3bc1bc604e3c154e43/lib/elixir/lib/uri.ex#L1013-L1019
  defp append_path(%Discharge{location: %URI{path: path} = uri}, "/" <> rest = all) do
    cond do
      path == nil -> %{uri | path: all}
      path != "" and :binary.last(path) == ?/ -> %{uri | path: path <> rest}
      true -> %{uri | path: path <> all}
    end
  end

  defp headers(%Discharge{auth: a}, %URI{host: h}, base \\ []) do
    case Map.get(a, h) do
      nil -> base
      val -> Keyword.put(base, :Authorization, val)
    end
  end
end
