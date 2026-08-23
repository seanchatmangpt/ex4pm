# Reactor information plane — v26.8.22

## Preserve

The canonical `ex4pm_core` semantic graph remains the source of truth. Reactor is the default
information-execution plane, not a replacement ontology and not a new ambient authority surface.

The information path preserves:

```text
raw request
  -> protocol normalization
  -> capability admission | typed refusal
  -> pending information receipt
  -> Reactor execution
  -> existing Ex4pm / Ash public API
  -> underlying analytical receipt where applicable
  -> terminal information receipt
  -> protocol envelope
  -> replay
```

Only `manifest`, `list`, and `describe` bypass Reactor. They are one-hop reads over the static
capability graph and do not execute a handler or manufacture an execution receipt.

## 2030 implication

The v26.8.22 architecture assumes that an apparently simple answer tends to become a graph by
2030: provenance, input normalization, policy, type casting, candidate selection, retries,
cross-runtime calls, observability, evidence, and replay become part of the answer's standing.
Therefore the stable unit of interoperability is an admitted Reactor intent and its evidence
envelope, not an incidental CLI function.

This does not mean every getter becomes a workflow. The direct fast path remains for genuinely
trivial introspection where an extra execution graph would manufacture no additional evidence.

## DfCM

The information plane preserves simultaneous lawful edges instead of selecting one universal
runtime:

- native BEAM/in-process calls;
- escript human/process calls;
- JSONL over stdio;
- existing BEAM, ex4pm-plan, WASM, NIF, and remote analytical engines;
- wasm4pm as a portable WASM client;
- pm4py as a Python/reference client;
- clap-noun-verb-any as a generated CLI client;
- MCP as a future tool projection.

A candidate recorded in the manifest is not an ALIVE claim. Exact execution against the admitted
subject is still required.

## Authority

Protocol data never becomes executable authority.

- capability strings are matched against a closed registry;
- resource/action strings are matched against loaded Ash public metadata;
- `Module.concat`, `String.to_atom`, dynamic `apply`, and arbitrary callback dispatch are absent;
- `ash.read` permits only public `:read` actions;
- generic Ash mutation is explicitly not admitted;
- `runtime.operate` is preserved as a future candidate but is not admitted from raw JSON;
- all state-changing runtime execution remains exclusively behind `Ex4pm.Evidence.BRCE`.

## Protocol

Protocol identity:

```text
ex4pm.information/1
release 26.8.22
```

A request is one JSON object:

```json
{
  "protocol": "ex4pm.information/1",
  "version": "26.8.22",
  "request_id": "client-generated-or-omitted",
  "capability": "process.discover",
  "input": {
    "subject": {
      "objects": {},
      "events": {}
    },
    "object_type": "Order"
  },
  "options": {
    "engine": "beam",
    "algorithm": "dfg"
  },
  "limits": {
    "timeout_ms": 30000,
    "max_concurrency": 4,
    "async": true
  }
}
```

The response binds protocol identity, request identity, standing, result, Reactor provenance, the
information pending/outcome receipts, and any underlying analytical receipt.

## Canonical DFG interchange

Internal DFG maps use tuple keys. Those tuples are not a public wire format. The information plane
projects edges as arrays:

```json
{
  "type": "dfg",
  "object_type": "Order",
  "activities": {
    "create": 2,
    "ship": 2
  },
  "edges": [
    {
      "source": "create",
      "target": "ship",
      "count": 2,
      "average_duration_ms": 90000.0
    }
  ],
  "starts": {
    "create": 2
  },
  "ends": {
    "ship": 2
  },
  "trace_count": 2
}
```

This representation round-trips through `process.simulate`, `process.conform`, and
`process.optimize`, so a wasm4pm or pm4py client does not need Elixir term conventions.

## CLI

Build the existing escript and inspect the direct graph:

```bash
mix escript.build -C apps/ex4pm_cli
./apps/ex4pm_cli/ex4pm manifest
./apps/ex4pm_cli/ex4pm list
./apps/ex4pm_cli/ex4pm describe process.discover
```

Execute an admitted capability:

```bash
./apps/ex4pm_cli/ex4pm run engine.candidates \
  '{"input":{"operation":"discover"}}'
```

Run the process-oriented JSONL server:

```bash
./apps/ex4pm_cli/ex4pm stdio
```

Each non-empty input line is one request and each output line is one JSON response.

## wasm4pm and pm4py interop

Both runtimes can use the same process boundary:

```text
client -> stdin JSONL -> ex4pm Reactor -> admitted capability -> receipt envelope -> stdout JSONL
```

No language-specific callback authority crosses this boundary. A future native client may replace
stdio with WIT, NIF, port, or network transport without changing the capability or receipt model.

## Bounds

v26.8.22 admits:

- JSON request body up to 32 MiB;
- protocol timeout: 1..120000 ms;
- Reactor concurrency: 1..64;
- simulation max depth: 1..256;
- simulation max paths: 1..10000;
- regular-file input only;
- file size up to 64 MiB.

These are admission bounds, not claims that every workload at the maximum bound has been
performance-qualified.

## Falsifiers

The information rail is not ALIVE if any of the following is observed for the exact subject:

- a non-trivial CLI command bypasses Reactor;
- an unknown capability reaches a handler;
- an external string manufactures an atom/module/callback;
- a private or mutating Ash action executes through `ash.read`;
- a handler is attempted without a pending information receipt;
- an attempted handler lacks a terminal information receipt;
- an underlying analytical receipt is dropped from the response;
- DFG JSON fails discovery-to-simulation round-trip;
- malformed protocol input actuates;
- exact-head `mix verify` is non-zero;
- replay of the information outcome receipt fails.

## Prior art used

The implementation builds on public Ash/Reactor patterns rather than inventing a parallel workflow
runtime:

- Reactor's `Reactor.run/4` and module-step DSL;
- Reactor's existing CLI-oriented `reactor.run` / `reactor.mermaid` tooling;
- Ash `Ash.Resource.Info.public_actions/1` guidance for public API construction;
- Ash `Ash.Query.for_read/4` and `Ash.read/2` for public read actions;
- Ash `Ash.Type.cast_input/3` and `apply_constraints/3` for input admission;
- AshOps' pattern of exposing Ash resource actions as command-line operations.

The ex4pm information plane extends those patterns with closed capability admission, DfCM candidate
preservation, layered receipts, replay, and a language-neutral JSONL contract.
