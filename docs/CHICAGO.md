# Chicago global-BEAM qualification

The Chicago crown is an executable qualification boundary for ex4pm. It is not a synonym for a large unit-test suite and it does not promote configuration or source inspection into runtime standing.

## Non-circular worlds

1. **Requirement world** — OTP distribution, supervision, authority, backpressure, replay, durability, engine and security invariants.
2. **Manufactured topology** — an origin node plus three real OTP `peer` nodes, high fan-out POWL models, failure injection, Broadway pressure, and real Wasmtime.
3. **Observed system** — public ex4pm APIs, the POWL runtime, BRCE, receipt stores, distributed runtime, Broadway and engine adapters.
4. **Evidence world** — exact node/toolchain identities, semantic hashes, task placements, receipt chains, timings/counts, refusal codes, transport posture and replay outcomes.
5. **Independent qualification** — origin-side receipt recomputation, local/distributed semantic parity and explicit falsifiers. Requirement text itself is never accepted as proof.

## Standing rules

- A local execution may earn `ALIVE` only for the exact local subject that executed.
- Same-host `peer` execution may earn `ALIVE` only for that exact distributed topology.
- Plain cookie-based Erlang distribution is `BLOCKED` for global-production network security.
- An `inet_tls` execution can prove encrypted distribution on the exact CI topology, but remains `PARTIAL_ALIVE` for global production until real multi-host/multi-region identity, latency, partition and certificate policy are observed.
- `:erpc` timeout or connection loss is not success. Because OTP documents that the remote function may or may not have executed, ex4pm reports an ambiguity-bearing typed refusal.
- Remote application exceptions must terminate in a blocked BRCE outcome receipt when the executing node remains reachable.
- Receipt-shaped data is not evidence until replay recomputes its hash and chain.
- NIF and generic remote-engine candidates retain their existing bounded standing until their exact native/remote identities are independently bound.

## Qualification command

```bash
mix chicago
```

The root alias runs only tests tagged `:chicago` with deterministic ExUnit seed `0`. `mix verify` remains the repository-wide verifier.

GitHub Actions runs the crown twice on the exact head:

1. ordinary Erlang distribution, where the test must explicitly report global network security as blocked;
2. TLS Erlang distribution using an ephemeral CI certificate, where encrypted transport is directly observed.

Both jobs emit identity-bound JSON artifacts. Those artifacts are execution receipts for their scoped topology, not claims that a same-host GitHub runner is a global multi-region production deployment.

## Falsifiers

The crown fails if any of the following occurs:

- exact source identity drifts;
- peer nodes do not run the same ERTS identity;
- local and distributed executions diverge semantically;
- distributed placement or receipt cardinality is incomplete;
- a remote receipt fails independent replay;
- origin receipt mirroring fails;
- a lost node is relabeled success;
- an ambiguous `:erpc` failure loses its ambiguity marker;
- a remote exception lacks a terminal blocked receipt;
- bounded high fan-out exceeds its coordinator concurrency cap;
- the durable DETS candidate loses a completed receipt across restart;
- the supervised volatile store does not restart;
- Broadway drops, duplicates, or fails to acknowledge admitted observations;
- the real Wasmtime path fails;
- plain distribution is promoted to global-production `ALIVE`;
- locked dependencies, warnings-as-errors, formatting, umbrella tests, or the dedicated Chicago command fail.
