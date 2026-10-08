# ex4pm v26.8.22 — Architecture Requirements Document

## 1. Architectural invariant

The CMCA architecture is a three-repository correspondence, not three implementations:

```text
BCINR                         wasm4pm                         ex4pm
-----                         -------                         -----
canonical CMCA mathematics -> portable WASM projection    -> analytical admission
fixed-point types             exact source pin               engine candidate
semantic registries           ABI/JS boundary                receipt composition
refusal semantics             artifact/replay evidence       SELECT/DO fence
```

Ownership SHALL remain:

- **BCINR** owns CMCA semantics and mathematics.
- **wasm4pm** owns the portable WebAssembly projection and execution evidence.
- **ex4pm** owns orchestration, evidence composition, explicit selection, BRCE-controlled execution, and standing.

No downstream repository SHALL fork or independently reinterpret the allocator mathematics.

## 2. Exact identities

### BCINR

Repository: `seanchatmangpt/bcinr`

Admitted source:

`b76dcb377b297cb8826a5256b55f8b57a6b76462`

Crate: `bcinr-cmca` version `26.7.28` at that Git subject.

Kernel:

`bcinr_cmca::allocator::allocate_single_lens`

The published registry crate with the same version is a different source object and SHALL NOT satisfy this identity requirement merely because package/version labels match.

### wasm4pm

Repository: `seanchatmangpt/wasm4pm`

Branch: `feat/bcinr-cmca-wasm-export`

PR: `#611`.

The final exact source SHA consumed by ex4pm SHALL be the exact head that passes the CMCA WASM court. Moving that head requires ex4pm requalification.

### ex4pm

Repository: `seanchatmangpt/ex4pm`

Base for v26.8.22 CMCA integration:

`56f0129a98cea1c85ca172dd8d34131e555d1726`

Branch: `feat/v26.8.22-bcinr-cmca-wasm`.

## 3. BCINR source architecture

BCINR already provides the authoritative CMCA fixed-shape allocator and generated semantic registry.

The portable v26.8.22 rail SHALL consume:

- `PackedSemanticState`;
- `LensSpec`;
- `NonNegativeFixed`;
- `SignedFixed`;
- generated dimensions `N=8`, `F=10`, `K=4`, `Q=4`;
- generated RDF input digest;
- generated source digest;
- `allocate_single_lens`;
- `LensSelectionRefusal`.

### Excluded BCINR surface

The full adaptive `allocate` authority rail SHALL not be used by wasm4pm until BCINR's own admission/proof fence grants it standing.

This is not a missing bridge feature. It is an explicit authority exclusion.

## 4. wasm4pm adapter architecture

`crates/wasm4pm-cmca` is a boundary adapter.

It SHALL be independently buildable as:

- Rust `rlib` for host tests;
- `cdylib` for WebAssembly generation.

Its dependency SHALL point to the exact BCINR Git source.

### Request object

`CmcaAllocationRequest` SHALL preserve the BCINR fixed shape:

```text
states[8]
  id
  factors_q16[10]

lenses[4]
  id
  q_q16

measure
lens_index
parent[8]
weights_q16[8][8]
```

The adapter SHALL perform representation conversion only. It SHALL not add an alternate allocation formula.

### Result object

The result contains exactly the BCINR allocation shares for the selected measure/lens:

```text
shares_q16[8]
```

### Computation receipt

The wasm4pm receipt is deterministic evidence for one CMCA computation.

It SHALL bind:

- schema;
- BCINR repository;
- exact BCINR source SHA;
- package and version;
- RDF input digest;
- generator source digest;
- kernel identity;
- authority domain;
- no-actuation flag;
- canonical request BLAKE3;
- canonical result BLAKE3;
- receipt BLAKE3.

This receipt is not an ex4pm BRCE receipt.

## 5. WebAssembly ABI

The first host ABI is wasm-bindgen/JavaScript because it permits exact structured request/result transfer without inventing an unrelated historical wasm4pm string ABI.

Exports SHALL include:

### `cmcaContract()`

Returns the executable contract identity including exact BCINR source, package, generated semantic digests, kernel, fixed shape, authority, and no-actuation declaration.

### `cmcaAllocate(request)`

Executes `allocate_single_lens` through the generated WASM artifact.

Domain refusals SHALL be returned as errors and SHALL preserve stable typed refusal codes.

### `cmcaReplay(response)`

Independently recomputes the computation receipt identity and verifies source/authority/no-actuation invariants.

Replay SHALL be invoked as a separate host operation. The existence of a receipt object is not replay.

## 6. wasm4pm standing model

The wasm4pm bridge SHALL have separate evidence states:

- **inspection**: crate/export exists;
- **native execution**: Rust adapter executed;
- **WASM construction**: `.wasm` artifact built;
- **WASM execution**: real host invoked exported computation;
- **replay**: host separately invoked `cmcaReplay`;
- **artifact identity**: exact WASM digest observed.

Only the conjunction required by the release claim may be called `ALIVE`.

## 7. ex4pm engine architecture

`Ex4pm.Engine.CmcaWasm` SHALL implement `Ex4pm.Engine`.

Registry ID: `:cmca_wasm`.

Operation: `:cmca`.

Algorithm identity: `:consequence_allocation`.

The engine SHALL use an injected two-argument transport callback, analogous to the existing ex4pm-plan boundary.

This callback is the placement/runtime boundary. It may invoke Node, a WASI host, a container, remote worker, Kubernetes job, or another lawful execution surface, but those transport details SHALL not become canonical CMCA semantics.

## 8. ex4pm admission algorithm

Given `(request, response, observed_identity)`, the engine SHALL evaluate:

```text
response ALIVE
AND result is present
AND receipt schema exact
AND BCINR source exact
AND package/version exact
AND kernel exact
AND authority == CONSTRUCT_ONLY
AND actuation_performed == false
AND request/result/receipt hashes present
AND observed wasm4pm source exact
AND observed wasm artifact digest present
AND separately executed cmcaReplay == true
```

If response semantics are valid but no observed artifact identity exists, standing is capped at `PARTIAL_ALIVE`.

If an observed identity contradicts the admitted source or replay evidence, return a typed refusal.

Contradiction SHALL never be represented as mere absence of evidence.

## 9. ex4pm public orchestration

`Ex4pm.cmca/2` SHALL:

1. require a map-shaped admitted CMCA request;
2. default engine selection to `:cmca_wasm`;
3. execute through `Ex4pm.Engine`;
4. create an analytical pending receipt;
5. persist it before manufacturing the outcome receipt;
6. persist the outcome receipt;
7. return `%Ex4pm.Run{operation: :cmca}`;
8. allow public chain-aware replay through `Ex4pm.replay/2`.

No BRCE call occurs in this path.

## 10. Receipt DAG

The cross-repository evidence DAG is:

```text
BCINR exact source SHA
      |
      v
wasm4pm source SHA
      |
      +-> WASM artifact SHA-256
      |
      +-> CMCA request BLAKE3
      +-> CMCA result BLAKE3
      +-> CMCA computation receipt BLAKE3
      +-> cmcaReplay == true
      |
      v
ex4pm CMCA engine evidence
      |
      +-> analytical pending receipt
      +-> analytical outcome receipt
      |
      v
Ex4pm.replay -> chain_match
```

No edge in this DAG grants DO authority.

## 11. Planning composition

The planner and CMCA engine SHALL compose through explicit data transformation rather than hidden control flow.

Target composition:

```text
ProcessIR / world observation
-> candidate preservation
-> planner alternatives
-> candidate-to-CMCA semantic projection
-> one or more CMCA consequence allocations
-> currentness/independence evidence
-> explicit SELECT artifact
-> CONSTRUCT artifact
-> BRCE authority admission
-> DO
```

The candidate-to-CMCA projection SHALL eventually become a canonical semantic transform with correspondence tests. Until then, callers must supply an explicit CMCA request rather than ex4pm fabricating missing BCINR factor values.

## 12. Currentness and evidence independence

CMCA evidence SHALL compose with, not bypass, the existing capsule currentness and evidence-independence calculi.

A mathematically valid CMCA computation can still be stale for a moved target.

Multiple CMCA executions sharing one source/runtime/artifact lineage SHALL not automatically count as independent corroboration.

## 13. Semantic mapping target

The 10 generated BCINR factor identities SHALL become the semantic bridge between ex4pm enterprise/process observations and CMCA.

The future mapping layer SHALL preserve source ontology/provenance and refuse missing factor semantics rather than invent values.

The target is:

```text
public ontology/application profile
-> SHACL admission
-> SemanticIR / ProcessIR
-> explicit BCINR factor projection
-> CMCA request
```

Ash remains an operational projection and SHALL not become the hidden source of CMCA factor truth.

## 14. Runtime portability

The first implementation uses wasm-bindgen + Node for the executable court.

Future hosts MAY include:

- browser JS;
- Wasmtime;
- WASI component hosts;
- OCI workers;
- cloud/serverless schedulers.

A new host extends the candidate graph. It SHALL not replace a verified host without explicit selection.

A future WIT/component-model CMCA world SHOULD preserve the same request, result, refusal, identity, replay, and authority semantics.

## 15. Security and authority

The CMCA WASM module SHALL import no business actuator by default.

The ex4pm CMCA adapter SHALL possess no provider credential.

The CMCA result SHALL not call `operate/3` automatically.

Only an explicit later selection/construction path may produce an object offered to BRCE, and BRCE SHALL independently admit authority before consequential execution.

## 16. Cross-repository exact-head court

The final ex4pm integration workflow SHALL:

1. checkout exact ex4pm head;
2. run ex4pm focused CMCA tests;
3. checkout exact wasm4pm CMCA head;
4. verify the wasm4pm source identity;
5. resolve exact BCINR Git dependency;
6. build the CMCA WASM artifact;
7. execute `cmcaContract`;
8. execute `cmcaAllocate`;
9. execute `cmcaReplay`;
10. observe exact WASM digest;
11. feed the exact response and execution identity into `Ex4pm.cmca/2`;
12. require ex4pm standing `:alive`;
13. require ex4pm public receipt replay `:chain_match`;
14. emit a machine-readable cross-repository receipt.

## 17. Falsifiers

The architecture is falsified for the affected rail if any of these occur:

- wasm4pm silently resolves the registry CMCA instead of the exact Git subject;
- two package labels are treated as equivalent without source proof;
- adapter math diverges from BCINR because logic was copied downstream;
- cyclic hierarchy produces a successful allocation;
- a receipt-shaped object substitutes for `cmcaReplay` execution;
- ex4pm accepts the wrong BCINR SHA;
- ex4pm accepts the wrong wasm4pm SHA;
- ex4pm reaches ALIVE without a WASM artifact digest;
- CMCA is allowed to choose or execute a candidate automatically;
- CMCA evidence bypasses BRCE for consequential action;
- evidence from one exact head crowns another.

## 18. Extension law

The fixed `N=8/F=10/K=4/Q=4` rail is the first portable certified topology, not a claim that arbitrary-shape consequence analysis is impossible.

Future arbitrary-shape, multi-lens, adaptive, or formally admitted rails SHALL be added as new explicit candidates with their own identity, bounds, proofs, receipts, and standing. One unavailable edge SHALL remain topology, not graph failure.
