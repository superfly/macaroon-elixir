defmodule Macfly do
  import Macfly.LowLevel

  def attenuate(target_location, header, caveats) do
    with {:ok, macaroons} <- parse_tokens(header),
         {:ok, macaroons} <- attenuate_tokens(target_location, macaroons, caveats_to_wire(caveats)),
         {:ok, toks} <- encode_tokens(macaroons) do
      {:ok, "FlyV1 #{toks}"}
    else
      error -> error
    end
  end

  def new(key, kid, location, caveats \\ []), do: Macfly.LowLevel.new(key, new_nonce(kid), location, caveats_to_wire(caveats))
end
