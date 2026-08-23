defmodule Ex4pm.Qualification.Powl.ReferenceOracle do
  @moduledoc "Independent declarative POWL 2.0 language oracle."

  alias Ex4pm.Qualification.Powl.TraceCanonicalizer
  alias Ex4pmEngine.POWL.Language

  def language(model, bound) when is_integer(bound) and bound >= 0 do
    model
    |> Language.evaluate(max_unroll: bound, max_depth: max(4, (bound + 1) * 16))
    |> TraceCanonicalizer.canonicalize()
  end
end
