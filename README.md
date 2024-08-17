# Macfly

This library handles Fly.io Macaroon encoding, decoding, attentuation, etc..

[Hex Docs](https://hexdocs.pm/macfly/)

## Installation

The package can be installed by adding `macfly` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:macfly, "~> 0.2.16"}
  ]
end
```

## Usage

### Encoding and Decoding

Tokens separated by commas:

```elixir
# for example tokens, see the tests or test/vectors.json file
token = "FlyV1 fm2_lJPE...,...,"

# supports single token or tokens that are seprated by commas
{:ok, [%Macfly.Macaroon{}] = macaroons} = Macfly.decode(token)

token = Macfly.encode(macaroons)
```

Single macaroon:

```elixir
# decode a single token (note: token without prefix FlyV1)
{:ok, %Macfly.Macaroon{} = macaroon} = Macfly.Macaroon.decide("fm2_lJPE...")

# encode a single token (note: token without prefix FlyV1)
token = Macfly.Macaroon.encode(macaroon)
```

### Attenuating a Macaroon

Tokens separated by commas:

```elixir
# for example tokens, see the tests or test/vectors.json file
token = "FlyV1o fm2_lJPE..,..., ..."
{:ok, [%Macfly.Macaroon{}] = macaroons} = Macfly.decode(token)

caveats = [
  %Macfly.Caveat.Organization{
    id: 1234,
    permission: Macfly.Action.read()
  }
]

options = %Macfly.Options{location: "29745b8fbe60e62fe8359198aea82643"}
          |> Macfly.Options.with_caveats([Macfly.Caveat.Organization])

new_macaroons = Macfly.attenuate(macaroons, caveats, options)

new_token = Macfly.encode(new_macaroons)
```

Single macaroon:

```elixir
{:ok, %Macfly.Macaroon{} = macaroon} = Macfly.Macaroon.decode("fm2_lJPE...")

caveats = [
  %Macfly.Caveat.Organization{
    id: 1234,
    permission: Macfly.Action.read()
  }
]

macaroon = Macfly.Macaroon.attenuate(macaroon, caveats)

token = Macfly.Macaroon.encode(macaroon)
```

## Documentation

To generate documentation locally run `mix docs` and open `doc/index.html` in your browser.
