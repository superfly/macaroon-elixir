defmodule Macfly.DischargeTest do
  alias Macfly.Discharge
  use ExUnit.Case
  doctest Macfly.Discharge

  test "init immediate discharge" do
    d =
      %Discharge{
        location: URI.parse("https://location"),
        ticket: "do discharge"
      }
      # shouldn't be sent
      |> Discharge.with_bearer_auth("some other location", "some auth")

    %{state: {:success, "my discharge"}} = Discharge.next(d)
  end

  test "init poll response" do
    d =
      %Discharge{
        location: URI.parse("https://location"),
        ticket: "do poll"
      }

    %{state: {:poll, "/poll/do_discharge"}} = Discharge.next(d)
  end

  test "init user interactive response" do
    d =
      %Discharge{
        location: URI.parse("https://location"),
        ticket: "do user interactive"
      }

    %{state: {:user_interactive, "https://location/user", "/poll/do_discharge"}} =
      Discharge.next(d)
  end

  test "init error response" do
    d =
      %Discharge{
        location: URI.parse("https://location"),
        ticket: "do error"
      }

    %{state: {:error, "my error"}} = Discharge.next(d)
  end

  test "init 500 response" do
    d =
      %Discharge{
        location: URI.parse("https://location"),
        ticket: "do 500"
      }

    %{state: {:error, {:bad_json, 500, _, _}}} = Discharge.next(d)
  end

  test "init bogus response" do
    d =
      %Discharge{
        location: URI.parse("https://location"),
        ticket: "do bogus"
      }

    %{state: {:error, {:bad_response, %{}}}} = Discharge.next(d)
  end

  test "init sends auth" do
    d =
      %Discharge{
        location: URI.parse("https://location"),
        ticket: "require auth"
      }
      |> Discharge.with_bearer_auth("some other location", "some auth")
      |> Discharge.with_bearer_auth("location", "correct")

    %{state: {:success, "my discharge"}} = Discharge.next(d)
  end

  test "poll discharge" do
    for base_state <- [{:poll}, {:user_interactive, "https://user"}] do
      d =
        %Discharge{
          state: Tuple.append(base_state, "/poll/do_discharge"),
          location: URI.parse("https://location"),
          ticket: "do poll"
        }
        # shouldn't be sent
        |> Discharge.with_bearer_auth("some other location", "some auth")

      %{state: {:success, "my discharge"}} = Discharge.next(d)
    end
  end

  test "poll full url" do
    for base_state <- [{:poll}, {:user_interactive, "https://user"}] do
      d =
        %Discharge{
          state: Tuple.append(base_state, "https://location/poll/do_discharge"),
          location: URI.parse("https://location"),
          ticket: "do poll"
        }

      %{state: {:success, "my discharge"}} = Discharge.next(d)
    end
  end

  test "poll not ready" do
    for base_state <- [{:poll}, {:user_interactive, "https://user"}] do
      d =
        %Discharge{
          state: Tuple.append(base_state, "/poll/not_ready"),
          location: URI.parse("https://location"),
          ticket: "do poll"
        }

      %{state: {:poll, "/poll/not_ready"}} = Discharge.next(d)
    end
  end

  test "poll error" do
    for base_state <- [{:poll}, {:user_interactive, "https://user"}] do
      d =
        %Discharge{
          state: Tuple.append(base_state, "/poll/do_error"),
          location: URI.parse("https://location"),
          ticket: "do poll"
        }

      %{state: {:error, "my error"}} = Discharge.next(d)
    end
  end

  test "poll 500" do
    for base_state <- [{:poll}, {:user_interactive, "https://user"}] do
      d =
        %Discharge{
          state: Tuple.append(base_state, "/poll/do_500"),
          location: URI.parse("https://location"),
          ticket: "do poll"
        }

      %{state: {:error, {:bad_json, 500, _, _}}} = Discharge.next(d)
    end
  end

  test "poll bogus" do
    for base_state <- [{:poll}, {:user_interactive, "https://user"}] do
      d =
        %Discharge{
          state: Tuple.append(base_state, "/poll/do_bogus"),
          location: URI.parse("https://location"),
          ticket: "do poll"
        }

      %{state: {:error, {:bad_response, %{}}}} = Discharge.next(d)
    end
  end

  test "poll sends auth" do
    for base_state <- [{:poll}, {:user_interactive, "https://user"}] do
      d =
        %Discharge{
          state: Tuple.append(base_state, "/poll/require_auth"),
          location: URI.parse("https://location"),
          ticket: "do poll"
        }
        # shouldn't be sent
        |> Discharge.with_bearer_auth("some other location", "some auth")
        |> Discharge.with_bearer_auth("location", "correct")

      %{state: {:success, "my discharge"}} = Discharge.next(d)
    end
  end
end
