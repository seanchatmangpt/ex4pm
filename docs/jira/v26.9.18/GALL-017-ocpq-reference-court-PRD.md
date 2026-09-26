# PRD v26.9.18 — GALL-017: OCPQ Reference Court

**Status:** FINAL_SPEC — closed for v26.9.24  
**Implementation standing:** PARTIAL_ALIVE via PR #47 (gall/v26.9.18-final-specs; originally 75b9e47b, compile fixes + hardening at 8a68c2c9, court repair on top of b74753fd): lib/ex4pm/gall.ex, test/gall_v26_9_18_test.exs, test/gall_v26_9_18_hardening_test.exs, test/gall_v26_9_18_repair_test.exs, benchmark receipt benchmarks/gall_v26_9_18_bench_receipt.json. AC1-AC5 executed in ex4pm; AC6 (consumption by wasm4pm GALL-023) UNVERIFIED in this repository.  
**Release:** v26.9.18  
**Repository:** `seanchatmangpt/ex4pm`  
**Owner:** ex4pm  
**Dependencies:** GALL-015 corpus, OCEL-compatible process evidence  
**Authority ceiling:** QUERY/QUALIFY only

## Product outcome
A canonical executable OCPQ qualification suite proves positive bindings, negative violations, deterministic verdicts and object/event identity semantics on the reference corpus.

## Problem
Object-centric process queries can look plausible while binding the wrong objects, events or qualifiers. A reference court is required before OCPQ results can feed conformance or planning evidence.

## Functional requirements
1. Define exact query syntax/AST and object/event/qualifier binding semantics used by ex4pm.
2. Create positive fixtures whose expected bindings are explicit and structural.
3. Create negative/adversarial fixtures for wrong object type, qualifier, temporal/order and multiplicity relations.
4. Return deterministic typed bindings/violations, not free-form prose.
5. Bind query digest, corpus digest and evaluator identity into each verdict.
6. Prove equivalent input ordering does not change semantic result.

## Acceptance criteria
1. Positive reference queries return exact expected object/event binding sets.
2. Each named negative fixture yields the named violation/refusal.
3. Input event/object ordering permutation preserves result.
4. Changing query text/AST changes query identity.
5. Missing load-bearing relation cannot produce a vacuous PASS.
6. Reference verdict is consumable by wasm4pm GALL-023.

## Evidence product
The product emits a content-addressed receipt binding exact process/corpus/model/algorithm identities, executed court, falsifiers and evidence ceiling. Prediction, discovery and selection remain explicitly weaker than admitted truth or authority.

## Definition of done
A canonical executable OCPQ qualification suite proves positive bindings, negative violations, deterministic verdicts and object/event identity semantics on the reference corpus.
