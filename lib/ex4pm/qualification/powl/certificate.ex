defmodule Ex4pm.Qualification.Powl.Certificate do
  @moduledoc false
  alias Ex4pm.Core.Hash

  def new(bound, oracle, compiled, fragments) do
    payload = %{
      bound: bound,
      oracle_language_hash: Hash.digest(oracle),
      compiled_language_hash: Hash.digest(compiled),
      fragment_hashes: Enum.map(fragments, & &1.plan_hash),
      trace_count: length(oracle),
      soundness: oracle == compiled,
      completeness: oracle == compiled,
      compiler_refinement: Enum.all?(fragments, & &1.refined)
    }

    Map.put(payload, :certificate_hash, Hash.digest(payload))
  end
end
