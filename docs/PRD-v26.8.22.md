# ex4pm v26.8.22 — Product Requirements Document

## 1. Release identity and product boundary

ex4pm v26.8.22 is the BEAM orchestration and evidence layer for process intelligence, planning, consequence allocation, controlled execution, receipt replay, and bounded standing.

The release SHALL preserve this authority sequence:

```text
observe -> parse -> route -> admit/refuse -> preserve candidates -> plan
-> CMCA consequence allocation -> SELECT -> CONSTRUCT -> BRCE -> DO
-> receipt -> replay -> standing
```

`CMCA != SELECT != CONSTRUCT != DO`.

CMCA SHALL never be an actuator. A CMCA result is evidence about consequences and allocation, not authority to choose or execute a change.

## 2. Canonical cross-repository ownership

v26.8.22 SHALL use one canonical ownership graph rather than duplicating CMCA implementations.

### BCINR — canonical CMCA mathematics

Repository: `seanchatmangpt/bcinr`

Admitted CMCA source for the first portable rail:

`b76dcb377b297cb8826a5256b55f8b57a6b76462`

Canonical crate: `bcinr-cmca`.

Canonical exported kernel for this release:

`bcinr_cmca::allocator::allocate_single_lens`

The first certified portable shape is the BCINR fixed deterministic shape:

- semantic objects `N = 8`
- factors `F = 10`
- measures `K = 4`
- lenses `Q = 4`
- Q16.16 fixed-point input/output
- explicit hierarchy and allocation weights

The arbitrary-shape slow rail remains a separate BCINR capability. The adaptive full allocator authority path SHALL remain excluded from this release while its BCINR proof/admission fence remains unresolved.

### wasm4pm — portable WebAssembly projection

Repository: `seanchatmangpt/wasm4pm`

Implementation PR: `#611`, branch `feat/bcinr-cmca-wasm-export`.

wasm4pm SHALL import the exact BCINR Git source rather than copying CMCA mathematics or relying on a stale published crate.

The `wasm4pm-cmca` crate SHALL provide:

- `cdylib` and `rlib` outputs;
- `cmcaAllocate` WebAssembly/JavaScript export;
- `cmcaReplay` WebAssembly/JavaScript replay verifier;
- `cmcaContract` exact identity contract;
- typed BCINR refusal preservation;
- deterministic BLAKE3 request/result/receipt identity;
- no credential, network, deployment, BRCE, or actuator capability.

### ex4pm — analytical consumer and evidence composition

Repository: `seanchatmangpt/ex4pm`.

v26.8.22 SHALL expose `Ex4pm.cmca/2` as a first-class analytical operation implemented by `Ex4pm.Engine.CmcaWasm`.

ex4pm SHALL NOT reimplement the CMCA mathematics. It SHALL admit the result of the exact wasm4pm artifact only when source, artifact, protocol, replay, and authority evidence correspond.

## 3. Exact-source requirements

### PR-CMCA-001 — BCINR is the semantic and mathematical source of truth

The wasm4pm CMCA bridge SHALL be pinned to an exact BCINR Git SHA. A crates.io package with the same package/version label SHALL not be treated as equivalent unless exact artifact equivalence is separately established.

### PR-CMCA-002 — one admitted kernel identity

Every successful CMCA computation receipt SHALL bind:

- BCINR repository;
- exact BCINR source SHA;
- CMCA package/version;
- generated RDF input digest;
- generator source digest;
- kernel identity;
- request digest;
- result digest;
- receipt digest;
- `CONSTRUCT_ONLY` authority;
- `actuation_performed=false`.

### PR-CMCA-003 — stale source refusal

ex4pm SHALL refuse a CMCA receipt that names any BCINR source other than its admitted source.

## 4. WASM execution requirements

### PR-WASM-001 — real WASM execution

The release SHALL execute the generated WebAssembly artifact through a real host boundary. Successful native Rust execution alone is insufficient to crown the WASM rail.

### PR-WASM-002 — replay is execution, not shape inspection

The host SHALL invoke `cmcaReplay` separately after `cmcaAllocate` and record the result. A response containing fields named `receipt` or `receipt_blake3` is not replay evidence by itself.

### PR-WASM-003 — exact artifact identity

The exact `.wasm` bytes SHALL be hashed and the observed digest SHALL accompany any ex4pm promotion to `ALIVE`.

### PR-WASM-004 — typed refusal preservation

At minimum, the portable boundary SHALL preserve typed refusal semantics for:

- invalid measure index;
- invalid lens index;
- excessive lens magnitude;
- cyclic hierarchy.

Refusals SHALL never be converted into successful allocation values.

## 5. ex4pm admission requirements

### PR-EX4PM-CMCA-001 — explicit engine candidate

`:cmca_wasm` SHALL be a registered engine candidate supporting operation `:cmca`.

A configured transport is only `PARTIAL_ALIVE` until execution evidence exists.

### PR-EX4PM-CMCA-002 — analytical public API

`Ex4pm.cmca/2` SHALL produce a normal analytical `Ex4pm.Run` and SHALL use the existing pending/outcome receipt chain.

### PR-EX4PM-CMCA-003 — ALIVE admission

A CMCA engine result may reach `ALIVE` only when all of the following are observed for one execution:

1. response standing is `ALIVE`;
2. response schema matches the wasm4pm CMCA contract;
3. BCINR source SHA matches exactly;
4. package/version/kernel match exactly;
5. receipt authority is `CONSTRUCT_ONLY`;
6. `actuation_performed=false`;
7. request/result/receipt digests are present;
8. wasm4pm source SHA matches the pinned export head;
9. actual WASM artifact digest is present;
10. `cmcaReplay` executed successfully.

Absent observed artifact identity SHALL cap standing at `PARTIAL_ALIVE`.

Wrong observed source or failed replay SHALL be typed `REFUSED`, not silently downgraded.

### PR-EX4PM-CMCA-004 — ex4pm receipt composition

The admitted CMCA result SHALL then enter ex4pm's own analytical pending/outcome receipt chain. Public `Ex4pm.replay/2` SHALL establish `:chain_match` for the ex4pm receipt.

The wasm4pm computation receipt and ex4pm analytical receipt are different receipts with different subjects and purposes; neither SHALL be renamed into the other.

## 6. Planning and consequence-allocation semantics

Planning and CMCA SHALL remain distinct.

`Ex4pm.plan/2` answers which candidate plans satisfy an admitted planning problem.

`Ex4pm.cmca/2` answers how an admitted BCINR consequence lens allocates consequence mass across the fixed semantic state.

The target composition is:

```text
candidate graph
  -> planner/solver alternatives
  -> semantic projection into BCINR CMCA request
  -> CMCA consequence allocation
  -> consequence evidence set
  -> explicit SELECT
  -> CONSTRUCT
  -> BRCE
  -> DO
```

v26.8.22 SHALL NOT infer that the highest, lowest, or otherwise preferred CMCA allocation is automatically selected.

## 7. DfCM requirements

CMCA SHALL enrich the candidate graph rather than collapse it prematurely.

- Failed CMCA evaluation of one candidate is topology, not graph failure.
- Alternative planners, runtimes, lenses, and transports remain lawful candidates until selection.
- Candidate consequence vectors SHALL remain associated with their exact candidate identities.
- Computational budget exhaustion SHALL preserve partial results and explicit standing.

## 8. Semantic requirements

The existing ex4pm ProcessIR, capsule currentness, evidence-independence, and public contract surfaces remain canonical ex4pm inputs to future CMCA projection work.

The Fortune-5 semantic target remains:

```text
public ontology + application profile + SHACL
-> SemanticIR / ProcessIR
-> candidate graph
-> BCINR CMCA semantic state
-> wasm4pm CMCA execution
-> ex4pm evidence composition
```

v26.8.22 SHALL not claim that the current hand-authored Ash/ETS resources or ex4pm-local ontology already complete this public-ontology-first mapping.

## 9. Authority requirements

No component in the following set has ambient DO authority:

- BCINR CMCA kernel;
- wasm4pm CMCA adapter;
- WebAssembly artifact;
- CMCA receipt;
- ex4pm CMCA engine;
- planner output;
- ProcessIR;
- ontology statements;
- Ash projections;
- tests or workflow results.

Only `Ex4pm.Evidence.BRCE` may cross the consequential DO boundary after explicit authority admission.

## 10. Verification ladder

The CMCA rail SHALL be validated in this order:

1. exact wasm4pm source identity;
2. exact BCINR Git dependency identity;
3. native `wasm4pm-cmca` positive and falsifier tests;
4. `wasm32-unknown-unknown` compilation;
5. wasm-pack artifact build;
6. Node-hosted `cmcaContract` execution;
7. Node-hosted `cmcaAllocate` execution;
8. Node-hosted `cmcaReplay` execution;
9. exact WASM hash and execution transcript receipt;
10. ex4pm adapter unit/falsifier tests;
11. public `Ex4pm.cmca/2` receipt-chain test;
12. exact cross-repository BCINR -> wasm4pm/WASM -> ex4pm integration court;
13. exact-head workflow/log/artifact inspection.

## 11. Release standing

No release-wide `ALIVE` claim may be manufactured from merge status, workflow presence, configured adapters, or source inspection.

The CMCA rail is `ALIVE` only for the exact BCINR source, exact wasm4pm source/artifact, exact ex4pm source, request, runtime, and replay evidence that actually executed.

All broader claims remain bounded by their own courts.
