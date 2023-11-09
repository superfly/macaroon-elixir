defmodule Macfly.Discharge do
  alias __MODULE__
  alias Macfly.HTTP

  @enforce_keys [:location, :ticket]
  defstruct location: nil,
            ticket: nil,
            state: :init,
            auth: %{}

  @type t() :: %Discharge{
          location: URI.t(),
          ticket: binary(),
          state: state(),
          auth: map()
        }

  @init_path "/.well-known/macfly/3p"
  @json_header ["Content-Type": "application/json"]

  @type state() ::
          :init
          | {:poll, String.t()}
          | {:user_interactive, String.t(), String.t()}
          | {:success, String.t()}
          | {:error, any()}

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

  def next(%Discharge{state: :init} = d), do: do_init(d, url(d, @init_path))

  def next(%Discharge{state: {:poll, poll_url}} = d) do
    u = url(d, poll_url)
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
    do: %Discharge{d | state: {:error, {:failed_request, e}}}

  defp handle_init_response({:ok, %HTTPoison.MaybeRedirect{status_code: s, redirect_url: r}}, d)
       when s in [307, 308] do
    do_init(d, url(d, r))
  end

  defp handle_init_response({:ok, %HTTPoison.Response{status_code: status, body: body}}, d) do
    case JSON.decode(body) do
      {:ok, %{"error" => error}} ->
        %Discharge{d | state: {:error, error}}

      {:ok, %{"discharge" => discharge}} ->
        %Discharge{d | state: {:success, discharge}}

      {:ok, %{"poll_url" => poll_url}} ->
        %Discharge{d | state: {:poll, poll_url}}

      {:ok, %{"user_interactive" => %{"user_url" => user_url, "poll_url" => poll_url}}} ->
        user_url = url(d, user_url) |> to_string
        %Discharge{d | state: {:user_interactive, user_url, poll_url}}

      {:ok, j} ->
        %Discharge{d | state: {:error, {:bad_response, j}}}

      {:error, error} ->
        %Discharge{d | state: {:error, {:bad_json, status, body, error}}}
    end
  end

  defp handle_init_response({:ok, r}, d),
    do: %Discharge{d | state: {:error, {:unexpected_response, r}}}

  defp handle_poll_response({:ok, %HTTPoison.Response{status_code: 202}}, d), do: d

  defp handle_poll_response({:error, e}, d),
    do: %Discharge{d | state: {:error, {:failed_request, e}}}

  defp handle_poll_response({:ok, %HTTPoison.Response{status_code: status, body: body}}, d) do
    case JSON.decode(body) do
      {:ok, %{"error" => error}} ->
        %Discharge{d | state: {:error, error}}

      {:ok, %{"discharge" => discharge}} ->
        %Discharge{d | state: {:success, discharge}}

      {:ok, j} ->
        %Discharge{d | state: {:error, {:bad_response, j}}}

      {:error, error} ->
        %Discharge{d | state: {:error, {:bad_json, status, body, error}}}
    end
  end

  defp handle_poll_response({:ok, r}, d),
    do: %Discharge{d | state: {:error, {:unexpected_response, r}}}

  defp url(%Discharge{location: l}, path), do: URI.merge(l, path)

  defp headers(%Discharge{auth: a}, %URI{host: h}, base \\ []) do
    case Map.get(a, h) do
      nil -> base
      val -> Keyword.put(base, :Authorization, val)
    end
  end
end
