# Macfly

This library handles Fly.io Macaroon encoding, decoding, attentuation, etc..

[Hex Docs](https://hexdocs.pm/macfly/)

## Installation

The package can be installed by adding `macfly` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:macfly, "~> 0.2.15"}
  ]
end
```

## Usage

### Encoding and Decoding

```elixir
# for example tokens, see the tests or test/vectors.json file
token = "FlyV1 fm2_lJPE..."

{:ok, [%Macfly.Macaroon{}] = macaroons} = Macfly.decode(token)

token = Macfly.encode(macaroons)
```

### Attenuating a Macaroon

```elixir
# for example tokens, see the tests or test/vectors.json file
token = "FlyV1o fm2_lJPE..."
{:ok, [%Macfly.Macaroon{}] = macaroons} = Macfly.decode(token)

caveats = [
  %Macfly.Caveat.Organization{
    id: 1234,
    permission: Macfly.Action.read()
  }
]

options = %Macfly.Options{location: "abcd"}
          |> Macfly.Options.with_caveats([Macfly.Caveat.Organization])

new_macaroons = Macfly.attenuate(macaroons, caveats, options)

new_token = Macfly.encode(new_macaroons)
```

## Documentation

To generate documentation locally run `mix docs` and open `doc/index.html` in your browser.
