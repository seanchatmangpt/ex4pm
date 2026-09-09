# Frontier Release Process Intelligence

`Ex4pm.Information.FrontierRelease` is the deterministic process-intelligence layer for the ecosystem Frontier Release Factory.

It deliberately begins after semantic extraction. Article retrieval and LLM interpretation are upstream observation/candidate concerns. Ex4pm receives normalized facts and computes:

- whether a source observation is structurally admissible;
- whether a response opportunity uses one of the bounded DfCM response modes;
- whether its benchmark has a metric, acceptance predicate and falsifier;
- whether the observed factory trace moves monotonically through its declared lifecycle;
- which working-backwards claims are supported by exact-subject ALIVE evidence.

## Earned-release calculus

For working-backwards claims `W` and evidence receipts `E`:

```text
Earned = {w in W | exists e in E: e.claim_id = w.id and e.standing = ALIVE
                    and e binds subject + verifier + receipt + replay}
```

Claims outside `Earned` are withheld. One failed claim edge does not invalidate independently proven claims. An empty `Earned` set is `BLOCKED`, not an invitation to publish prose as evidence.

The result carries `publication_authority: :none`. Ex4pm computes evidence/conformance; it never turns that computation into repository creation, deployment, external communication, spending, or publication authority.

## Lifecycle

The v1 ordered stages are:

```text
observe -> extract -> fence -> invert -> specify -> manufacture -> verify -> publish
```

Repeated stages are lawful; moving backward is a typed `:stage_regression` refusal. More expressive OCEL/conformance analysis can extend this primitive without changing the authority ceiling.

## Cross-repository split

- `ggen-marketplace`: canonical reusable Frontier Release Factory vocabulary/projections.
- `xaas`: persistent operator/product surface.
- `beam4pm`: generated BEAM record/process representation.
- `ex4pm`: deterministic process intelligence and conformance calculations.
- `chatman-ecosystem`: cross-repository routing, standing and authority policy.

## Falsifiers

This slice is invalid if it performs external DO, promotes non-ALIVE evidence, silently accepts incomplete evidence, invents unknown response modes, or treats an external source release as execution standing.
