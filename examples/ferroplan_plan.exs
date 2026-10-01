# Run: mix run examples/ferroplan_plan.exs
#
# Plans a classical PDDL problem with the bundled, sha256-pinned ferroplan
# wasm artifact (priv/ferroplan). Real execution, no stubs. A missing or
# mismatched artifact prints the typed refusal instead of raising.
alias Ex4pm.Engine.Ferroplan

domain = File.read!("test/support/fixtures/ferroplan/logistics_domain.pddl")
problem = File.read!("test/support/fixtures/ferroplan/logistics_p1.pddl")

IO.puts("artifact:    #{Ferroplan.artifact_path()}")
IO.puts("wasm_built?: #{Ferroplan.wasm_built?()}")

case Ferroplan.version() do
  {:ok, v} -> IO.puts("version:     #{inspect(v)}")
  {:error, r} -> IO.puts("version REFUSED: #{inspect(r)}")
end

case Ferroplan.plan(domain, problem) do
  {:ok, response} -> IO.puts("plan response:\n#{inspect(response, pretty: true, limit: 20)}")
  {:error, refusal} -> IO.puts("plan REFUSED: #{inspect(refusal)}")
end

# Receipt-bearing result with standing, via the Ex4pm.Engine behaviour:
case Ferroplan.execute(:ferroplan_plan, %{domain: domain, problem: problem}, []) do
  {:ok, r} -> IO.puts("standing: #{r.standing}  executed: #{r.evidence.executed}  sha256: #{r.evidence.wasm_sha256}")
  {:error, refusal} -> IO.puts("execute REFUSED: #{inspect(refusal)}")
end
