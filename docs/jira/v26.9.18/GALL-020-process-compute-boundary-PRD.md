# PRD v26.9.18 — GALL-020: Process Compute Boundary

**Status:** FINAL_SPEC — closed for v26.9.24  
**Implementation standing:** OPEN in PR #47 (gall/v26.9.18-final-specs @ 75b9e47b: lib/ex4pm/gall.ex + test/gall_v26_9_18_test.exs; not on main)  
**Release:** v26.9.18  
**Repository:** `seanchatmangpt/ex4pm`  
**Owner:** ex4pm  
**Dependencies:** GALL-015..019  
**Authority ceiling:** SELECT computation; deterministic algorithm computes result

## Product outcome
ex4pm exposes typed process-computation capabilities so models/planners may select a computation, while deterministic algorithms execute it and return receipted results.

## Problem
Using an LLM or agent to both choose and perform process calculations makes results expensive, hard to reproduce and semantically ambiguous. Intelligence should select machinery, not substitute for deterministic process algorithms.

## Functional requirements
1. Define typed capability descriptors for process queries, conformance, discovery, POWL conversion and prediction evaluation.
2. Separate computation selection from computation execution.
3. Validate input schemas before algorithm dispatch.
4. Bind exact algorithm/version/parameters/corpus subject to result.
5. Permit non-LLM callers to invoke the same capabilities directly.
6. No model-generated numerical/process result may bypass the deterministic algorithm where an admitted capability exists.
7. Emit execution-cost/latency evidence without converting it into authority.

## Acceptance criteria
1. Same admitted computation invoked by LLM-selected and deterministic caller routes yields same algorithm/result identity.
2. Malformed inputs refuse before compute.
3. Replacing algorithm version changes receipt identity.
4. Known process computation executes with zero model requirement.
5. Attempt to submit model-authored result as computed truth is refused.
6. Capabilities are consumable by wasm4pm or SA2A adapters without conversation protocol.

## Evidence product
The product emits a content-addressed receipt binding exact process/corpus/model/algorithm identities, executed court, falsifiers and evidence ceiling. Prediction, discovery and selection remain explicitly weaker than admitted truth or authority.

## Definition of done
ex4pm exposes typed process-computation capabilities so models/planners may select a computation, while deterministic algorithms execute it and return receipted results.
