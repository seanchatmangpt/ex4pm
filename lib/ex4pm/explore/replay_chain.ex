defmodule Ex4pm.Explore.ReplayChain do
  @moduledoc false

  def append(chain, payload) when is_list(chain) do
    previous = case List.last(chain) do nil -> String.duplicate("0", 64); entry -> entry.digest end
    digest = Ex4pm.Explore.SemanticIdentity.sha256({previous, payload})
    chain ++ [%{previous: previous, payload: payload, digest: digest}]
  end

  def verify(chain) do
    Enum.reduce_while(chain, String.duplicate("0", 64), fn entry, previous ->
      expected = Ex4pm.Explore.SemanticIdentity.sha256({previous, entry.payload})
      if entry.previous == previous and entry.digest == expected, do: {:cont, entry.digest}, else: {:halt, false}
    end) != false
  end
end
