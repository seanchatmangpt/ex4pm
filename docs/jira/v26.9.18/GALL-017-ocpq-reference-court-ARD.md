# ARD v26.9.18 — GALL-017: OCPQ Reference Court

**Status:** DRAFT ARCHITECTURE SPEC  
**Release:** v26.9.18  
**Repository:** `seanchatmangpt/ex4pm`  
**Owner:** ex4pm  
**Dependencies:** GALL-015 corpus, OCEL-compatible process evidence  
**Authority ceiling:** QUERY/QUALIFY only

## Architecture objective
A canonical executable OCPQ qualification suite proves positive bindings, negative violations, deterministic verdicts and object/event identity semantics on the reference corpus.

## Components
- OCPQ parser/AST
- object-centric binding evaluator
- reference query corpus
- typed verdict/violation model
- deterministic result canonicalizer
- receipt emitter

## Data/control flow
`OCPQ + exact OCEL/corpus subject -> parse/validate -> binding evaluation -> typed result/violations -> canonical digest/receipt`

## Invariants
1. Define exact query syntax/AST and object/event/qualifier binding semantics used by ex4pm.
2. Create positive fixtures whose expected bindings are explicit and structural.
3. Create negative/adversarial fixtures for wrong object type, qualifier, temporal/order and multiplicity relations.
4. Return deterministic typed bindings/violations, not free-form prose.
5. Bind query digest, corpus digest and evaluator identity into each verdict.
6. Prove equivalent input ordering does not change semantic result.

## Failure/refusal boundaries
- Malformed query => REFUSED
- Missing required object/event relation => violation, not empty-success
- Unsupported operator => UNSUPPORTED
- Nondeterministic binding order => qualification failure

## Qualification court
- mix format --check-formatted
- mix compile --warnings-as-errors
- focused OCPQ reference tests
- input-order permutation tests
- mix test

## Standing law
[
Observed \neq Normative,\quad Prediction \neq Fact,\quad Candidate \neq Authority,\quad Selection \neq ComputationResult
]

Generated/discovered models never rewrite admitted law merely because they fit observations.
