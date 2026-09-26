# ARD v26.9.18 — GALL-016: POWL Dual Ingress

**Status:** FINAL_SPEC — closed for v26.9.24  
**Implementation standing:** IMPLEMENTED via PR #47 (gall/v26.9.18-final-specs, originally 75b9e47b; compile fixes + adversarial hardening at 8a68c2c9): lib/ex4pm/gall.ex, test/gall_v26_9_18_test.exs, test/gall_v26_9_18_hardening_test.exs, benchmark receipt benchmarks/gall_v26_9_18_bench_receipt.json  
**Release:** v26.9.18  
**Repository:** `seanchatmangpt/ex4pm`  
**Owner:** ex4pm  
**Dependencies:** GALL-015 corpus  
**Authority ceiling:** MODEL/CONSTRUCT only

## Architecture objective
ex4pm produces a validated canonical POWL/POWL-v2 representation from two independent ingress paths—semantic intent and WF-net/process decomposition—and proves semantic agreement on the shared reference corpus.

## Components
- semantic-intent -> POWL compiler
- WF-net/decomposition -> POWL converter
- canonical POWL data model
- structural validator
- semantic equivalence/property comparator
- POWL receipt emitter

## Data/control flow
`Semantic intent -> POWL_A; WF-net/decomposition -> POWL_B; validate -> compare shared semantic invariants -> canonical receipts`

## Invariants
1. Define canonical internal representation for sequence, partial order, choice, loop and hierarchy.
2. Ingress A compiles admitted semantic process intent into POWL.
3. Ingress B converts validated WF-net/process decomposition into POWL.
4. Preserve hierarchy and partial-order relations; do not flatten merely to simplify serialization.
5. Validate both outputs against structural POWL invariants before standing.
6. Compare semantic properties rather than textual ordering where multiple equivalent encodings exist.
7. Emit source-ingress identity and canonical POWL digest.

## Failure/refusal boundaries
- Unsupported construct => UNSUPPORTED, not silently flattened
- Invalid partial order/hierarchy => REFUSED
- Two ingress semantics disagree => BLOCKED/PARTIAL
- Source identity unavailable => no standing

## Qualification court
- mix format --check-formatted
- mix compile --warnings-as-errors
- focused POWL dual-ingress tests against GALL-015 corpus
- mix test

## Standing law
[
Observed \neq Normative,\quad Prediction \neq Fact,\quad Candidate \neq Authority,\quad Selection \neq ComputationResult
]

Generated/discovered models never rewrite admitted law merely because they fit observations.
