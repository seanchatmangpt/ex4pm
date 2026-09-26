# ARD v26.9.18 — GALL-018: Rule-Constrained Discovery

**Status:** FINAL_SPEC — closed for v26.9.24  
**Implementation standing:** IMPLEMENTED via PR #47 (gall/v26.9.18-final-specs, originally 75b9e47b; compile fixes + adversarial hardening at 8a68c2c9): lib/ex4pm/gall.ex, test/gall_v26_9_18_test.exs, test/gall_v26_9_18_hardening_test.exs, benchmark receipt benchmarks/gall_v26_9_18_bench_receipt.json  
**Release:** v26.9.18  
**Repository:** `seanchatmangpt/ex4pm`  
**Owner:** ex4pm  
**Dependencies:** GALL-015 corpus, GALL-016 POWL, observed event evidence  
**Authority ceiling:** DISCOVER/CANDIDATE only

## Architecture objective
Process discovery produces candidate models only inside an admitted rule envelope, preserving explicit separation between normative constraints and observed behavior.

## Components
- rule-envelope representation
- event/corpus adapter
- discovery algorithm adapter
- constraint filter/checker
- candidate model set
- deviation report/receipt

## Data/control flow
`Observed evidence + admitted rules -> discovery candidates -> rule checking -> lawful candidate set + deviation evidence`

## Invariants
1. Accept admitted process rules/constraints as immutable inputs to one discovery run.
2. Discover candidate process structure from observed evidence without mutating normative rules.
3. Reject or mark candidates that violate required ordering, exclusion, cardinality or hierarchy constraints.
4. Emit observed deviations separately from candidate model structure.
5. Preserve multiple lawful candidates when evidence underdetermines one model.
6. Bind corpus/event subject, rule set, algorithm and parameters into discovery identity.

## Failure/refusal boundaries
- No lawful candidate => BLOCKED/DEVIATION, not rule mutation
- Rule identity missing => no constrained-standing
- Algorithm nondeterminism unbound => evidence ceiling reduced
- Candidate self-promoted to canonical process => architecture failure

## Qualification court
- focused constrained-discovery fixtures
- unlawful-candidate elimination falsifier
- normative-rule immutability test
- deterministic replay test

## Standing law
[
Observed \neq Normative,\quad Prediction \neq Fact,\quad Candidate \neq Authority,\quad Selection \neq ComputationResult
]

Generated/discovered models never rewrite admitted law merely because they fit observations.
