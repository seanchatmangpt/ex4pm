# PRD v26.9.18 — GALL-016: POWL Dual Ingress

**Status:** FINAL_SPEC — closed for v26.9.24  
**Implementation standing:** OPEN in PR #47 (gall/v26.9.18-final-specs @ 75b9e47b: lib/ex4pm/gall.ex + test/gall_v26_9_18_test.exs; not on main)  
**Release:** v26.9.18  
**Repository:** `seanchatmangpt/ex4pm`  
**Owner:** ex4pm  
**Dependencies:** GALL-015 corpus  
**Authority ceiling:** MODEL/CONSTRUCT only

## Product outcome
ex4pm produces a validated canonical POWL/POWL-v2 representation from two independent ingress paths—semantic intent and WF-net/process decomposition—and proves semantic agreement on the shared reference corpus.

## Problem
POWL is useful only if the same semantics can be reached from both explicit semantic process intent and discovered/decomposed workflow structure without one path silently redefining the other.

## Functional requirements
1. Define canonical internal representation for sequence, partial order, choice, loop and hierarchy.
2. Ingress A compiles admitted semantic process intent into POWL.
3. Ingress B converts validated WF-net/process decomposition into POWL.
4. Preserve hierarchy and partial-order relations; do not flatten merely to simplify serialization.
5. Validate both outputs against structural POWL invariants before standing.
6. Compare semantic properties rather than textual ordering where multiple equivalent encodings exist.
7. Emit source-ingress identity and canonical POWL digest.

## Acceptance criteria
1. Reference corpus sequential/parallel/choice/loop cases succeed through both ingress paths.
2. Hierarchical fixture retains parent/child structure.
3. Invalid cyclic/ill-formed partial-order fixture is refused.
4. Equivalent dual-ingress fixtures agree on required semantic properties.
5. Changing source subject changes POWL receipt identity.
6. No ingress path is treated as authority for the other without comparison.

## Evidence product
The product emits a content-addressed receipt binding exact process/corpus/model/algorithm identities, executed court, falsifiers and evidence ceiling. Prediction, discovery and selection remain explicitly weaker than admitted truth or authority.

## Definition of done
ex4pm produces a validated canonical POWL/POWL-v2 representation from two independent ingress paths—semantic intent and WF-net/process decomposition—and proves semantic agreement on the shared reference corpus.
