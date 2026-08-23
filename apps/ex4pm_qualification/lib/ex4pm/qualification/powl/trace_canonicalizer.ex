defmodule Ex4pm.Qualification.Powl.TraceCanonicalizer do
  @moduledoc "Canonicalizes the exact bounded POWL linear-trace language."

  @doc """
  Correspondence is deliberately stricter than causal-equivalence: each legal
  linear extension is a distinct trace. Concurrency therefore cannot hide a
  missing or extra Reactor execution order behind an equivalence class.
  """
  def canonicalize(traces) when is_list(traces) do
    traces
    |> Enum.map(fn trace -> Enum.map(trace, &to_string/1) end)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
