# ARD v26.9.18 — GALL-015: Process Reference Corpus

**Status:** FINAL_SPEC — closed for v26.9.24
**Implementation standing:** IMPLEMENTED via PR #47 (gall/v26.9.18-final-specs, originally 75b9e47b; compile fixes + adversarial hardening at 8a68c2c9): lib/ex4pm/gall.ex, test/gall_v26_9_18_test.exs, test/gall_v26_9_18_hardening_test.exs, benchmark receipt benchmarks/gall_v26_9_18_bench_receipt.json
**Release:** v26.9.18
**Repository:** `seanchatmangpt/ex4pm`
**Owner:** ex4pm
**Dependencies:** Public process semantics / existing ex4pm process model
**Authority ceiling:** MODEL/QUALIFY only

## Architecture objective
ex4pm owns a versioned process reference corpus containing canonical positive/negative fixtures, expected structural/process properties and deterministic qualification receipts reusable by POWL, OCPQ, discovery and predictor tickets.

## Components
- `test/fixtures` or repository-native corpus root
- corpus manifest/schema
- fixture loader
- expected-property evaluator
- corpus receipt/digest

## Data/control flow
`Process fixture sources -> manifest/content digest -> loader -> algorithm-specific court -> expected semantic properties/refusals`

## Invariants
1. Define corpus manifest with fixture ID, semantic subject, source format, expected properties, expected refusals and provenance.
2. Include sequential, parallel, choice, loop, partial-order, hierarchical and object-centric cases.
3. Include deliberately invalid/deceptive fixtures for anti-vacuity testing.
4. Keep expected results structural/semantic, not byte-for-byte implementation snapshots unless byte identity is itself the claim.
5. Version corpus independently and content-address every fixture.
6. Expose a repository-native API/helper for other ex4pm/wasm4pm courts to load exact fixtures.

## Failure/refusal boundaries
- Fixture cannot be parsed => corpus invalid
- Expected result ambiguous => fixture rejected
- Hidden external dependency => BLOCKED
- Consumer uses floating corpus => no standing

## Qualification court
- mix format --check-formatted
- mix compile --warnings-as-errors
- focused corpus loader/property tests
- mix test

## Standing law
[
Observed \neq Admitted,\quad Prediction \neq Fact,\quad Candidate \neq Authority,\quad SELECT \neq DO
]

PASS requires exact-subject positive execution plus the required negative witnesses. No missing layer may be synthesized in this repository merely to satisfy the crown.
