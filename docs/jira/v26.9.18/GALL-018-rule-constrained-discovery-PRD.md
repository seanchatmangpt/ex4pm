# PRD v26.9.18 — GALL-018: Rule-Constrained Discovery

**Status:** DRAFT IMPLEMENTATION SPEC  
**Release:** v26.9.18  
**Repository:** `seanchatmangpt/ex4pm`  
**Owner:** ex4pm  
**Dependencies:** GALL-015 corpus, GALL-016 POWL, observed event evidence  
**Authority ceiling:** DISCOVER/CANDIDATE only

## Product outcome
Process discovery produces candidate models only inside an admitted rule envelope, preserving explicit separation between normative constraints and observed behavior.

## Problem
Pure process discovery can fit observed traces while violating known normative rules. Conversely, normative law must not be rewritten merely because observations differ.

## Functional requirements
1. Accept admitted process rules/constraints as immutable inputs to one discovery run.
2. Discover candidate process structure from observed evidence without mutating normative rules.
3. Reject or mark candidates that violate required ordering, exclusion, cardinality or hierarchy constraints.
4. Emit observed deviations separately from candidate model structure.
5. Preserve multiple lawful candidates when evidence underdetermines one model.
6. Bind corpus/event subject, rule set, algorithm and parameters into discovery identity.

## Acceptance criteria
1. Unconstrained fixture yields candidate set containing expected structure.
2. Constraint eliminates a trace-fitting but unlawful candidate.
3. Observed rule violation is reported as deviation rather than rule rewrite.
4. Underdetermined fixture preserves multiple candidates or typed ambiguity.
5. Changing rule set changes discovery subject.
6. Deterministic algorithm/seed reproduces same candidate ranking/set.

## Evidence product
The product emits a content-addressed receipt binding exact process/corpus/model/algorithm identities, executed court, falsifiers and evidence ceiling. Prediction, discovery and selection remain explicitly weaker than admitted truth or authority.

## Definition of done
Process discovery produces candidate models only inside an admitted rule envelope, preserving explicit separation between normative constraints and observed behavior.
