defmodule Macfly.HTTP do
  @callback get(url :: URI.t(), headers :: Keyword.t()) :: {atom(), any()}
  @callback post(url :: URI.t(), body :: String.t(), headers :: Keyword.t()) :: {atom(), any()}

  def get(url, headers), do: impl().get(url, headers)
  def post(url, body, headers), do: impl().post(url, body, headers)
  def impl(), do: Application.get_env(:macfly, :http, Macfly.HTTP.Client)
end

defmodule Macfly.HTTP.Client do
  @behaviour Macfly.HTTP
  def get(url, headers), do: HTTPoison.get(to_string(url), headers)
  def post(url, body, headers), do: HTTPoison.post(to_string(url), body, headers)
end

defmodule Macfly.HTTP.Fake do
  @behaviour Macfly.HTTP

  @location "https://location"
  @key Macfly.Crypto.rand(32)
  @caveat_type 9999
  @options %Macfly.Options{}

  @type behavior() ::
          :discharge
          | :poll
          | :user_interactive
          | :error
          | :"500"
          | :bogus
          | :require_auth
          | :not_ready

  @spec ticket(list(behavior())) :: binary()
  def ticket(behaviors) do
    Macfly.Macaroon.new("foo", "bar", @options.location)
    |> add_third_party(behaviors)
    |> then(fn %Macfly.Macaroon{caveats: [%Macfly.Caveat.ThirdParty{ticket: t}]} -> t end)
  end

  @spec add_third_party(Macfly.Macaroon.t(), list(behavior())) :: Macfly.Macaroon.t()
  def add_third_party(m, behaviors) do
    Macfly.Macaroon.add_third_party(m, @location, @key, [
      %Macfly.Caveat.UnrecognizedCaveat{type: @caveat_type, body: behaviors}
    ])
  end

  defp get_behaviors(<<ticket::binary>>) do
    ticket
    |> Base.decode64!()
    |> Macfly.Caveat.ThirdParty.Ticket.recover(@key, @options)
    |> then(fn {:ok, %{caveats: [%{type: @caveat_type, body: body}]}} ->
      Enum.map(body, &String.to_atom/1)
    end)
  end

  def get(%{scheme: "https", host: "location", path: <<"/poll/", ticket::binary>>}, header) do
    with authz when authz in [nil, "Bearer correct"] <- Keyword.get(header, :Authorization) do
      ticket
      |> get_behaviors()
      |> do_behavior_poll(ticket, header)
    else
      _ -> {:ok, %HTTPoison.Response{status_code: 401, body: ""}}
    end
  end

  def do_behavior_poll([first, :discharge], t, _h) when first in [:poll, :user_interactive] do
    t
    |> Base.decode64!()
    |> Macfly.Caveat.ThirdParty.Ticket.discharge_macaroon(@key, @location)
    |> case do
      {:ok, %Macfly.Macaroon{} = m} ->
        m
        |> to_string()
        |> then(&%{discharge: &1})
        |> JSON.encode!()
        |> then(&{:ok, %HTTPoison.Response{status_code: 200, body: &1}})
    end
  end

  def do_behavior_poll([first, :not_ready], _t, _h) when first in [:poll, :user_interactive] do
    {:ok, %HTTPoison.Response{status_code: 202}}
  end

  def do_behavior_poll([first, :require_auth | rest], t, h)
      when first in [:poll, :user_interactive] do
    with "Bearer correct" <- Keyword.get(h, :Authorization) do
      do_behavior_poll([first | rest], t, h)
    else
      _ -> {:ok, %HTTPoison.Response{status_code: 401, body: ""}}
    end
  end

  def do_behavior_poll([first, :error], _t, _h) when first in [:poll, :user_interactive] do
    %{error: "my error"}
    |> JSON.encode!()
    |> then(&{:ok, %HTTPoison.Response{status_code: 400, body: &1}})
  end

  def do_behavior_poll([first, :"500"], _t, _h) when first in [:poll, :user_interactive] do
    {:ok, %HTTPoison.Response{status_code: 500, body: "internal server error"}}
  end

  def do_behavior_poll([first, :bogus], _t, _h) when first in [:poll, :user_interactive] do
    %{bogus: 123}
    |> JSON.encode!()
    |> then(&{:ok, %HTTPoison.Response{status_code: 200, body: &1}})
  end

  @init_uri %{scheme: "https", host: "location", path: "/.well-known/macfly/3p"}

  def post(@init_uri, body, header) do
    with "application/json" <- Keyword.get(header, :"Content-Type"),
         authz when authz in [nil, "Bearer correct"] <- Keyword.get(header, :Authorization) do
      body
      |> JSON.decode!()
      |> case do
        %{"ticket" => <<t::binary>>} ->
          t
          |> get_behaviors()
          |> do_behavior_init(t, header)
      end
    else
      _ -> {:ok, %HTTPoison.Response{status_code: 401, body: ""}}
    end
  end

  defp do_behavior_init([:discharge], t, _h) do
    t
    |> Base.decode64!()
    |> Macfly.Caveat.ThirdParty.Ticket.discharge_macaroon(@key, @location)
    |> case do
      {:ok, %Macfly.Macaroon{} = m} ->
        m
        |> to_string()
        |> then(&%{discharge: &1})
        |> JSON.encode!()
        |> then(&{:ok, %HTTPoison.Response{status_code: 201, body: &1}})
    end
  end

  defp do_behavior_init([:poll | _], t, _h) do
    %{poll_url: "/poll/" <> t}
    |> JSON.encode!()
    |> then(&{:ok, %HTTPoison.Response{status_code: 201, body: &1}})
  end

  defp do_behavior_init([:user_interactive | _], t, _h) do
    %{user_interactive: %{poll_url: "/poll/" <> t, user_url: "/user"}}
    |> JSON.encode!()
    |> then(&{:ok, %HTTPoison.Response{status_code: 201, body: &1}})
  end

  defp do_behavior_init([:error], _t, _h) do
    %{error: "my error"}
    |> JSON.encode!()
    |> then(&{:ok, %HTTPoison.Response{status_code: 400, body: &1}})
  end

  defp do_behavior_init([:"500"], _t, _h) do
    {:ok, %HTTPoison.Response{status_code: 500, body: "internal server error"}}
  end

  defp do_behavior_init([:bogus], _t, _h) do
    %{bogus: 123}
    |> JSON.encode!()
    |> then(&{:ok, %HTTPoison.Response{status_code: 201, body: &1}})
  end

  defp do_behavior_init([:require_auth | rest], t, header) do
    with "Bearer correct" <- Keyword.get(header, :Authorization) do
      do_behavior_init(rest, t, header)
    else
      _ -> {:ok, %HTTPoison.Response{status_code: 401, body: ""}}
    end
  end
end
