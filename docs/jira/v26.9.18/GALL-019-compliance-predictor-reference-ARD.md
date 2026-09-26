# ARD v26.9.18 — GALL-019: Compliance Predictor Reference

**Status:** FINAL_SPEC — closed for v26.9.24  
**Implementation standing:** IMPLEMENTED via PR #47 (gall/v26.9.18-final-specs, originally 75b9e47b; compile fixes + adversarial hardening at 8a68c2c9): lib/ex4pm/gall.ex, test/gall_v26_9_18_test.exs, test/gall_v26_9_18_hardening_test.exs, benchmark receipt benchmarks/gall_v26_9_18_bench_receipt.json  
**Release:** v26.9.18  
**Repository:** `seanchatmangpt/ex4pm`  
**Owner:** ex4pm  
**Dependencies:** GALL-015 corpus, GALL-017 OCPQ, GALL-018 constrained discovery  
**Authority ceiling:** PREDICT/CANDIDATE only

## Architecture objective
A reproducible reference predictor estimates future compliance/deviation from admitted process features, is benchmarked against simple baselines, and emits candidate-only predictions with calibrated evidence.

## Components
- process feature extractor
- baseline predictor
- qualified model adapter
- calibration/evaluation module
- candidate prediction schema
- model/evaluation receipt

## Data/control flow
`Admitted process evidence -> features -> baseline/model -> calibrated compliance/deviation prediction -> CANDIDATE evidence`

## Invariants
1. Define process feature schema from admitted OCPQ/discovery/state evidence.
2. Provide simple deterministic/statistical baseline before complex learned model.
3. Use leak-resistant train/validation/test splits by process/case identity.
4. Report precision/recall/calibration and class distribution, not only aggregate accuracy.
5. Bind model/data/features/threshold identity into prediction.
6. Prediction feeds planning/attention only as candidate evidence.
7. Include adversarial/deceptive cases from GALL-015/017 corpus.

## Failure/refusal boundaries
- Leakage detected => FAIL
- Unsupported model/runtime => UNSUPPORTED
- Uncalibrated score presented as fact => refusal
- Prediction used to mutate law => architecture failure

## Qualification court
- feature determinism test
- held-out evaluation
- leakage mutation falsifier
- candidate-standing enforcement test

## Standing law
[
Observed \neq Normative,\quad Prediction \neq Fact,\quad Candidate \neq Authority,\quad Selection \neq ComputationResult
]

Generated/discovered models never rewrite admitted law merely because they fit observations.
