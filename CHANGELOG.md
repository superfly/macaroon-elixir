# Changelog

## v0.2.22

- Restore optional `Jason.Encoder` support. v0.2.21 switched struct encoding to
  the built-in `JSON.Encoder` protocol (Elixir 1.18+), which broke callers using
  `Jason.encode!/1` on `Macfly` structs. All caveat structs and `Macfly.Action`
  now implement `Jason.Encoder` again when `:jason` is present, producing the
  same output as the built-in `JSON` encoding. Add `{:jason, "~> 1.4"}` to your
  deps to opt in; nothing is required otherwise.

## v0.2.21

- Replace HTTPoison with Req.
- Require Elixir ~> 1.18 and encode JSON with the built-in `JSON` module.
  **Breaking:** `Jason.Encoder` implementations were dropped in this release
  (restored in v0.2.22).
- Make `:jason` an optional dependency.
