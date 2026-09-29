# PRD v26.9.18 — GALL-015: Process Reference Corpus

**Status:** FINAL_SPEC — closed for v26.9.24
**Implementation standing:** OPEN in PR #47 (gall/v26.9.18-final-specs @ 75b9e47b: lib/ex4pm/gall.ex + test/gall_v26_9_18_test.exs; not on main)
**Release:** v26.9.18
**Repository:** `seanchatmangpt/ex4pm`
**Owner:** ex4pm
**Dependencies:** Public process semantics / existing ex4pm process model
**Authority ceiling:** MODEL/QUALIFY only

## Product outcome
ex4pm owns a versioned process reference corpus containing canonical positive/negative fixtures, expected structural/process properties and deterministic qualification receipts reusable by POWL, OCPQ, discovery and predictor tickets.

## Problem
Process algorithms cannot be compared or composed reliably without a stable corpus of positive, negative and boundary models whose expected semantics are executable rather than prose-only.

## Functional requirements
1. Define corpus manifest with fixture ID, semantic subject, source format, expected properties, expected refusals and provenance.
2. Include sequential, parallel, choice, loop, partial-order, hierarchical and object-centric cases.
3. Include deliberately invalid/deceptive fixtures for anti-vacuity testing.
4. Keep expected results structural/semantic, not byte-for-byte implementation snapshots unless byte identity is itself the claim.
5. Version corpus independently and content-address every fixture.
6. Expose a repository-native API/helper for other ex4pm/wasm4pm courts to load exact fixtures.

## Acceptance criteria
1. Each positive fixture validates its expected properties.
2. Each negative fixture triggers the named refusal/violation.
3. Corpus manifest digest changes with any fixture/property change.
4. At least one fixture exercises concurrency and one object-centric multi-object relation.
5. Consumer court can pin exact corpus digest.
6. No fixture depends on hidden local state.

## Evidence product
Emit a content-addressed checkpoint artifact/receipt binding exact repository SHA, predecessor identities, inputs, courts/falsifiers, outputs, standing and evidence ceiling.

## Release rules
Source presence, configuration, hosted workflow definitions and model scores are not runtime standing. UNKNOWN, PARTIAL, REFUSED, BLOCKED and UNSUPPORTED remain typed. Changed identities are changed subjects.

## Definition of done
ex4pm owns a versioned process reference corpus containing canonical positive/negative fixtures, expected structural/process properties and deterministic qualification receipts reusable by POWL, OCPQ, discovery and predictor tickets.
