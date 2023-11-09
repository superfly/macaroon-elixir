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

  @discharge_body %{discharge: "my discharge"} |> JSON.encode!()
  @error_body %{error: "my error"} |> JSON.encode!()
  @bogus_body %{bogus: 123} |> JSON.encode!()

  def get(%{scheme: "https", host: "location", path: "/poll/do_discharge"}, []) do
    {:ok, %HTTPoison.Response{status_code: 200, body: @discharge_body}}
  end

  def get(%{scheme: "https", host: "location", path: "/poll/not_ready"}, []) do
    {:ok, %HTTPoison.Response{status_code: 202}}
  end

  def get(%{scheme: "https", host: "location", path: "/poll/require_auth"},
        Authorization: "Bearer correct"
      ) do
    {:ok, %HTTPoison.Response{status_code: 200, body: @discharge_body}}
  end

  def get(%{scheme: "https", host: "location", path: "/poll/do_error"}, []) do
    {:ok, %HTTPoison.Response{status_code: 200, body: @error_body}}
  end

  def get(%{scheme: "https", host: "location", path: "/poll/do_500"}, []) do
    {:ok, %HTTPoison.Response{status_code: 500, body: "internal server error"}}
  end

  def get(%{scheme: "https", host: "location", path: "/poll/do_bogus"}, []) do
    {:ok, %HTTPoison.Response{status_code: 200, body: @bogus_body}}
  end

  @body %{ticket: "do discharge" |> Base.encode64()} |> JSON.encode!()

  def post(%{scheme: "https", host: "location", path: "/.well-known/macfly/3p"}, @body,
        "Content-Type": "application/json"
      ) do
    {:ok, %HTTPoison.Response{status_code: 201, body: @discharge_body}}
  end

  @body %{ticket: "require auth" |> Base.encode64()} |> JSON.encode!()

  def post(%{scheme: "https", host: "location", path: "/.well-known/macfly/3p"}, @body,
        Authorization: "Bearer correct",
        "Content-Type": "application/json"
      ) do
    {:ok, %HTTPoison.Response{status_code: 201, body: @discharge_body}}
  end

  @body %{ticket: "do poll" |> Base.encode64()} |> JSON.encode!()

  def post(%{scheme: "https", host: "location", path: "/.well-known/macfly/3p"}, @body,
        "Content-Type": "application/json"
      ) do
    %{poll_url: "/poll/do_discharge"}
    |> JSON.encode!()
    |> then(&{:ok, %HTTPoison.Response{status_code: 201, body: &1}})
  end

  @body %{ticket: "do user interactive" |> Base.encode64()} |> JSON.encode!()

  def post(%{scheme: "https", host: "location", path: "/.well-known/macfly/3p"}, @body,
        "Content-Type": "application/json"
      ) do
    %{user_interactive: %{poll_url: "/poll/do_discharge", user_url: "/user"}}
    |> JSON.encode!()
    |> then(&{:ok, %HTTPoison.Response{status_code: 201, body: &1}})
  end

  @body %{ticket: "do error" |> Base.encode64()} |> JSON.encode!()

  def post(%{scheme: "https", host: "location", path: "/.well-known/macfly/3p"}, @body,
        "Content-Type": "application/json"
      ) do
    {:ok, %HTTPoison.Response{status_code: 201, body: @error_body}}
  end

  @body %{ticket: "do 500" |> Base.encode64()} |> JSON.encode!()
  def post(%{scheme: "https", host: "location", path: "/.well-known/macfly/3p"}, @body,
        "Content-Type": "application/json"
      ) do
    {:ok, %HTTPoison.Response{status_code: 500, body: "internal server error"}}
  end

  @body %{ticket: "do bogus" |> Base.encode64()} |> JSON.encode!()
  def post(%{scheme: "https", host: "location", path: "/.well-known/macfly/3p"}, @body,
        "Content-Type": "application/json"
      ) do
    {:ok, %HTTPoison.Response{status_code: 201, body: @bogus_body}}
  end
end
