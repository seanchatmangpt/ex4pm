# ARD v26.9.18 — GALL-020: Process Compute Boundary

**Status:** FINAL_SPEC — closed for v26.9.24  
**Implementation standing:** IMPLEMENTED via PR #47 (gall/v26.9.18-final-specs, originally 75b9e47b; compile fixes + adversarial hardening at 8a68c2c9): lib/ex4pm/gall.ex, test/gall_v26_9_18_test.exs, test/gall_v26_9_18_hardening_test.exs, benchmark receipt benchmarks/gall_v26_9_18_bench_receipt.json  
**Release:** v26.9.18  
**Repository:** `seanchatmangpt/ex4pm`  
**Owner:** ex4pm  
**Dependencies:** GALL-015..019  
**Authority ceiling:** SELECT computation; deterministic algorithm computes result

## Architecture objective
ex4pm exposes typed process-computation capabilities so models/planners may select a computation, while deterministic algorithms execute it and return receipted results.

## Components
- typed process capability catalog
- selection envelope
- input validator
- deterministic algorithm dispatcher
- result/receipt schema
- non-LLM invocation adapter

## Data/control flow
`Caller/model/planner SELECTS capability -> validate exact input -> deterministic ex4pm algorithm executes -> result receipt -> downstream consumer`

## Invariants
1. Define typed capability descriptors for process queries, conformance, discovery, POWL conversion and prediction evaluation.
2. Separate computation selection from computation execution.
3. Validate input schemas before algorithm dispatch.
4. Bind exact algorithm/version/parameters/corpus subject to result.
5. Permit non-LLM callers to invoke the same capabilities directly.
6. No model-generated numerical/process result may bypass the deterministic algorithm where an admitted capability exists.
7. Emit execution-cost/latency evidence without converting it into authority.

## Failure/refusal boundaries
- No admitted algorithm => UNSUPPORTED
- Input invalid => REFUSED
- Model result supplied instead of compute => REFUSED
- Algorithm identity unavailable => no standing

## Qualification court
- capability-catalog tests
- model-selected vs direct-call equivalence test
- invalid-input falsifier
- zero-model known-computation witness
- mix test

## Standing law
[
Observed \neq Normative,\quad Prediction \neq Fact,\quad Candidate \neq Authority,\quad Selection \neq ComputationResult
]

Generated/discovered models never rewrite admitted law merely because they fit observations.
