defmodule Macfly.DischargeTest do
  alias Macfly.Discharge
  alias Macfly.HTTP.Fake
  use ExUnit.Case
  doctest Macfly.Discharge

  @location URI.parse("https://location")

  describe "init" do
    test "immediate discharge" do
      %{state: {:success, "fm2_" <> _}} =
        Discharge.new(
          location: @location,
          ticket: Fake.ticket([:discharge])
        )
        # shouldn't be sent
        |> Discharge.with_bearer_auth("some other location", "some auth")
        |> Discharge.next()
    end

    test "poll response" do
      %{state: {:poll, "/poll/" <> _}} =
        Discharge.new(
          location: @location,
          ticket: Fake.ticket([:poll, :discharge])
        )
        |> Discharge.next()
    end

    test "user interactive response" do
      %{state: {:user_interactive, "https://location/user", "/poll/" <> _}} =
        Discharge.new(
          location: @location,
          ticket: Fake.ticket([:user_interactive, :discharge])
        )
        |> Discharge.next()
    end

    test "error response" do
      %{state: {:error, "my error"}} =
        Discharge.new(
          location: @location,
          ticket: Fake.ticket([:error])
        )
        |> Discharge.next()
    end

    test "500 response" do
      %{state: {:error, {:bad_json, 500, _, _}}} =
        Discharge.new(
          location: @location,
          ticket: Fake.ticket([:"500"])
        )
        |> Discharge.next()
    end

    test "bogus response" do
      %{state: {:error, {:bad_response, %{}}}} =
        Discharge.new(
          location: @location,
          ticket: Fake.ticket([:bogus])
        )
        |> Discharge.next()
    end

    test "sends auth" do
      %{state: {:success, "fm2_" <> _}} =
        Discharge.new(
          location: @location,
          ticket: Fake.ticket([:require_auth, :discharge])
        )
        |> Discharge.with_bearer_auth("some other location", "some auth")
        |> Discharge.with_bearer_auth("location", "correct")
        |> Discharge.next()
    end
  end

  for first <- [:poll, :user_interactive] do
    describe "#{first}" do
      test "discharge" do
        %{state: {:success, "fm2_" <> _}} =
          Discharge.new(
            location: @location,
            ticket: Fake.ticket([unquote(first), :discharge])
          )
          # shouldn't be sent
          |> Discharge.with_bearer_auth("some other location", "some auth")
          |> Discharge.next()
          |> Discharge.next()
      end

      test "full url" do
        %{state: {:success, "fm2_" <> _}} =
          Discharge.new(
            location: @location,
            ticket: Fake.ticket([unquote(first), :discharge])
          )
          |> Discharge.next()
          |> then(fn
            %{state: {:poll, poll_url}} = d ->
              poll_url = URI.to_string(URI.merge(@location, poll_url))
              %{d | state: {:poll, poll_url}}

            %{state: {:user_interactive, user_url, poll_url}} = d ->
              poll_url = URI.to_string(URI.merge(@location, poll_url))
              %{d | state: {:user_interactive, user_url, poll_url}}
          end)
          |> Discharge.next()
      end

      test "not ready" do
        %{state: {:poll, _poll_url}} =
          Discharge.new(
            location: @location,
            ticket: Fake.ticket([unquote(first), :not_ready])
          )
          |> Discharge.next()
          |> Discharge.next()
      end

      test "error" do
        %{state: {:error, "my error"}} =
          Discharge.new(
            location: @location,
            ticket: Fake.ticket([unquote(first), :error])
          )
          |> Discharge.next()
          |> Discharge.next()
      end

      test "500" do
        %{state: {:error, {:bad_json, 500, _, _}}} =
          Discharge.new(
            location: @location,
            ticket: Fake.ticket([unquote(first), :"500"])
          )
          |> Discharge.next()
          |> Discharge.next()
      end

      test "bogus" do
        %{state: {:error, {:bad_response, %{}}}} =
          Discharge.new(
            location: @location,
            ticket: Fake.ticket([unquote(first), :bogus])
          )
          |> Discharge.next()
          |> Discharge.next()
      end

      test "sends auth" do
        %{state: {:success, "fm2_" <> _}} =
          Discharge.new(
            location: @location,
            ticket: Fake.ticket([unquote(first), :require_auth, :discharge])
          )
          # shouldn't be sent
          |> Discharge.with_bearer_auth("some other location", "some auth")
          |> Discharge.with_bearer_auth("location", "correct")
          |> Discharge.next()
          |> Discharge.next()
      end
    end
  end
end
