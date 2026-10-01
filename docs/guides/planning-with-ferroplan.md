# Planning with ferroplan

ferroplan (PDDL, HTN/HDDL, FOND) runs as an admitted `wasm32-wasip1` artifact bundled at
`priv/ferroplan/ferroplan_wasm.wasm`, pinned by `priv/ferroplan/MANIFEST.json`. Execution goes
through `Ex4pmEngine.Wasm.FerroplanTransport`; see `docs/FERROPLAN-RUNTIME.md` for the ABI.

Planning is **CONSTRUCT-only**: a plan is a candidate. Results (and any session-style use of the
artifact's `session_*` ops, which have no Elixir facade today) carry no DO authority; actuating a plan crosses `Ex4pm.Evidence.BRCE` like anything else.

## Selecting the engine

`:ferroplan` is explicit-only (rank 99 in the registry): pass `engine: :ferroplan`; it is never
chosen implicitly. Its operations are `:ferroplan_plan`, `:ferroplan_plan_production`,
`:ferroplan_readiness`, `:ferroplan_version`, `:ferroplan_hierarchical_plan`,
`:ferroplan_fond_policy`.

## Facade

`Ex4pm.Engine.Ferroplan` functions each return `{:ok, map} | {:error, term}`:

| Function | Purpose |
|---|---|
| `plan(domain, problem, extra \\ %{}, opts \\ [])` | PDDL planning (binary domain/problem) |
| `plan_production(domain, problem, extra, opts)` | production plan; result is candidate-only |
| `hierarchical_plan(problem_json, limits \\ nil, opts)` | HTN planning (PlanningProblem JSON text or map) |
| `fond_policy(problem_json, limits \\ nil, opts)` | FOND policy synthesis (response carries a validation report) |
| `hddl_solve(domain, problem, limits \\ nil, opts)` | HDDL text solve |
| `fond_policy_validate/3`, `fond_validate/3`, `explain/4` | policy validation and plan explanation |
| `readiness(opts)` / `version(opts)` | artifact health / guest version |
| `wasm_built?(opts)` / `available?(opts)` | file present / digest admitted |

Non-binary domain/problem yields a `:ferroplan_bad_input` refusal.

## Options

- `:ferroplan_artifact` - path to the wasm (default: bundled artifact; also
  `config :ex4pm, :ferroplan_artifact`).
- `:ferroplan_expected_sha256` - admitted digest, hex with optional `sha256:` prefix. Default:
  read from `MANIFEST.json` beside the artifact. With no pin the artifact is NOT admitted.
- `:timeout` - per-call timeout.

## Example

```elixir
alias Ex4pm.Engine.Ferroplan

domain  = File.read!("test/support/fixtures/ferroplan/logistics_domain.pddl")
problem = File.read!("test/support/fixtures/ferroplan/logistics_p1.pddl")

{:ok, %{"plan" => %{"steps" => steps}}} = Ferroplan.plan(domain, problem)

{:ok, result} = Ferroplan.execute(:ferroplan_plan, %{domain: domain, problem: problem}, [])
result.standing            #=> :alive
result.evidence.executed   #=> true
result.evidence.wasm_sha256
```

Runnable: `mix run examples/ferroplan_plan.exs`. Observed output (excerpt):

```text
wasm_built?: true
version:     %{"version" => "0.29.0"}
plan response: %{"mode" => "temporal", "plan" => %{"length" => 3, "makespan" => 4.002..., ...}}
standing: alive  executed: true  sha256: 088d9c3b0306e36123ddc1ee780ad7e9d4bd2ebb54f9726c43f40a2f6d718233
```

## Standing

`:alive` only when the digest was admitted AND the call executed in this run. An absent artifact
or digest mismatch is a typed refusal (`:ferroplan_artifact_missing`, `:ferroplan_digest_unpinned`,
`:ferroplan_digest_mismatch`, `:ferroplan_engine_error`, `:ferroplan_bad_input`), never a fallback
planner. `Ex4pm.plan/2` defaults to `:ex4pm_plan`; pass `engine: :ferroplan` to route here.
