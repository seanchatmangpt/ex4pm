defmodule Ex4pm.Qualification.Powl.Semantics do
  @moduledoc "Bounded POWL semantic identity used by the correspondence court."

  alias Ex4pm.Core.Hash
  alias Ex4pm.Qualification.Powl.ReferenceOracle

  def identity(model, bound) do
    language = ReferenceOracle.language(model, bound)

    %{
      bound: bound,
      language: language,
      semantics_hash: Hash.digest(%{bound: bound, language: language})
    }
  end
end
