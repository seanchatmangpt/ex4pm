# PRD v26.9.18 — GALL-019: Compliance Predictor Reference

**Status:** FINAL_SPEC — closed for v26.9.24  
**Implementation standing:** IMPLEMENTED via PR #47 (gall/v26.9.18-final-specs, originally 75b9e47b; compile fixes + adversarial hardening at 8a68c2c9): lib/ex4pm/gall.ex, test/gall_v26_9_18_test.exs, test/gall_v26_9_18_hardening_test.exs, benchmark receipt benchmarks/gall_v26_9_18_bench_receipt.json  
**Release:** v26.9.18  
**Repository:** `seanchatmangpt/ex4pm`  
**Owner:** ex4pm  
**Dependencies:** GALL-015 corpus, GALL-017 OCPQ, GALL-018 constrained discovery  
**Authority ceiling:** PREDICT/CANDIDATE only

## Product outcome
A reproducible reference predictor estimates future compliance/deviation from admitted process features, is benchmarked against simple baselines, and emits candidate-only predictions with calibrated evidence.

## Problem
Predicting future compliance or deviation can prioritize attention, but scores are not facts and must be qualified against process semantics and adversarial cases.

## Functional requirements
1. Define process feature schema from admitted OCPQ/discovery/state evidence.
2. Provide simple deterministic/statistical baseline before complex learned model.
3. Use leak-resistant train/validation/test splits by process/case identity.
4. Report precision/recall/calibration and class distribution, not only aggregate accuracy.
5. Bind model/data/features/threshold identity into prediction.
6. Prediction feeds planning/attention only as candidate evidence.
7. Include adversarial/deceptive cases from GALL-015/017 corpus.

## Acceptance criteria
1. Held-out reference corpus produces reproducible metrics.
2. Baseline and selected model are both reported.
3. Label/temporal leakage falsifier is detected.
4. Changing threshold/model changes prediction subject.
5. False-positive/false-negative behavior is visible in receipt.
6. Prediction cannot directly change normative process model or authority.

## Evidence product
The product emits a content-addressed receipt binding exact process/corpus/model/algorithm identities, executed court, falsifiers and evidence ceiling. Prediction, discovery and selection remain explicitly weaker than admitted truth or authority.

## Definition of done
A reproducible reference predictor estimates future compliance/deviation from admitted process features, is benchmarked against simple baselines, and emits candidate-only predictions with calibrated evidence.
