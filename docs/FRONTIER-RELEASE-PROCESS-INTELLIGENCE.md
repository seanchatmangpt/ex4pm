# Frontier Release Process Intelligence

`Ex4pm.Information.FrontierRelease` is the deterministic process-intelligence layer for the ecosystem Frontier Release Factory.

It deliberately begins after semantic extraction. Article retrieval and LLM interpretation are upstream observation/candidate concerns. Ex4pm receives normalized facts and computes:

- whether a source observation is structurally admitted as `OBSERVED` with no authority;
- whether a response opportunity uses one of the bounded DfCM response modes;
- whether its benchmark has a metric, acceptance predicate and falsifier;
- whether the observed factory trace moves monotonically through its declared lifecycle;
- which working-backwards claims are supported by exact-subject, exact-verifier ALIVE evidence.

## Earned-release calculus

For working-backwards claims `W`, evidence receipts `E`, admitted subject identity `S`, and admitted verifier identity `V`:

```text
Earned(S,V) = {w in W | exists e in E:
                         e.claim_id = w.id
                         and e.standing = ALIVE
                         and e.subject_identity = S
                         and e.verifier_identity = V
                         and e binds receipt + replay}
```

Evidence is grouped by claim and searched existentially. Receipt ordering therefore cannot erase a qualifying ALIVE edge. Duplicate working-claim identities are refused because the set member would otherwise be ambiguous.

Aggregate release standing is:

```text
BLOCKED       when Earned = {}
ALIVE         when Earned = W and W is non-empty
PARTIAL_ALIVE otherwise
```

Claims outside `Earned` are withheld. One failed claim edge does not invalidate independently proven claims. `PARTIAL_ALIVE` preserves those live edges without crowning the entire working-backwards claim set.

`qualify_release/3` requires the exact admitted subject and verifier binding. The two-argument form is a typed `:missing_release_binding` refusal; it cannot infer authority or identity from receipt-shaped input.

The result always carries `publication_authority: :none`. Ex4pm computes evidence/conformance; it never turns that computation into repository creation, deployment, external communication, spending, publication, or any other external DO authority.

## Evidence admission

Evidence receipts must contain non-empty claim, subject, verifier, receipt, and replay identities. Evidence standing must be one of the admitted vocabulary values:

```text
UNKNOWN | PARTIAL_ALIVE | ALIVE | BLOCKED | BUILD_BROKEN | UNSUPPORTED
```

Unknown standing labels are typed refusals. This layer does not dereference receipt or replay references and does not independently execute the named verifier. `ALIVE` remains an admitted evidence assertion whose exact subject and verifier must match the release qualification boundary.

## Lifecycle

The v1 ordered stages are:

```text
observe -> extract -> fence -> invert -> specify -> manufacture -> verify -> publish
```

Repeated stages are lawful; moving backward is a typed `:stage_regression` refusal. The `publish` symbol is an observed lifecycle state only; recognizing it does not grant publication authority. More expressive OCEL/conformance analysis can extend this primitive without changing the authority ceiling.

## Cross-repository split

- `ggen-marketplace`: canonical reusable Frontier Release Factory vocabulary/projections.
- `xaas`: persistent operator/product surface.
- `beam4pm`: generated BEAM record/process representation.
- `ex4pm`: deterministic process intelligence and conformance calculations.
- `chatman-ecosystem`: cross-repository routing, standing and authority policy.

## Falsifiers

This slice is invalid if any of the following occur:

- it performs RSS/article retrieval or any other external DO;
- it creates repositories, deploys, communicates, spends, or publishes;
- an ALIVE receipt for the wrong subject or verifier earns a claim;
- evidence ordering changes the earned claim set;
- a mixed earned/withheld set is crowned ALIVE;
- non-ALIVE evidence promotes a claim;
- incomplete evidence or unknown standings are silently accepted;
- an unadmitted source observation creates a candidate opportunity;
- an unknown response mode is invented;
- a lifecycle stage regresses;
- an external announcement is treated as execution standing.
