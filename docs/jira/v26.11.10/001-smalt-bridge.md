# ex4pm-001: Smalt OCEL-to-ex4pm File-Level Bridge

- **Standing**: VERIFIED
- **Created**: 2026-11-10 (v26.11.10 release campaign)
- **Author / Persona**: Systems Integration & Process Ingestion Engineer
- **Domain**: Cross-Repository Process Telemetry & OCEL 2.0 Ingestion
- **Target File**: `priv/smalt/powl_bridge.exs`

---

## 1. Context & Architecture

Process mining and object-centric telemetry in modern enterprise distributed environments require decoupling between log producers and analytical engines. The `smalt` repository generates rich OCEL 2.0 NDJSON telemetry via `Smalt.Telemetry.OcelNdjson.assemble_document/1`, mapping runtime telemetric events (`type` -> `activity`, `time` -> `timestamp`, `relationships` -> `object_ids`).

To preserve pure architectural separation:
1. `ex4pm` must never take a compile-time or runtime dependency on `smalt`.
2. `smalt` must never depend directly on the `ex4pm` BEAM app or its heavy native WASM dependencies.
3. The boundary is bridged at the file and CLI boundary via `priv/smalt/powl_bridge.exs`.

This script provides standard CLI subcommands for offline process discovery (`discover`) and conformance checking (`conform`) using pure JSON transport.

---

## 2. Scope & Technical Specification

### 2.1 File Location & Packaging
- Path: `priv/smalt/powl_bridge.exs`
- Included in Hex package via `mix.exs` `package.files: ["priv", ...]` (built clean in `ex4pm-26.11.10.tar`).
- Executable via standard Mix CLI runner: `elixir -S mix run priv/smalt/powl_bridge.exs <subcommand> <args...>`.

### 2.2 CLI Interfaces
1. **Discovery**:
   ```bash
   elixir -S mix run priv/smalt/powl_bridge.exs discover <in.json> <out.json> <object_type>
   ```
   - Ingests OCEL JSON via `SmaltBridge.ingest/1` -> `Ex4pm.ingest/1`.
   - Flattens event log per target `object_type` via `Ex4pm.OCEL.flatten/2`.
   - Discovers directly-follows graph (DFG) via `Ex4pm.discover(log, object_type: object_type)`.
   - Serializes model via `SmaltBridge.encode_model/1` (converting tuple edge keys `{{from, to}, meta}` into portable `{"from": "...", "to": "..."}` objects).
   - Writes structured JSON receipt including `standing`, `subject_hash`, `traces`, and `per_object_type` frequencies.

2. **Conformance**:
   ```bash
   elixir -S mix run priv/smalt/powl_bridge.exs conform <in.json> <model.json> <out.json> <object_type>
   ```
   - Ingests OCEL log and decodes stored DFG model via `SmaltBridge.decode_model/1`.
   - Runs `Ex4pm.conform(log, model, object_type: object_type)`.
   - Emits fitness report, alignment metrics, deviations, and cryptographic receipt.

### 2.3 Data Transformation Pipeline
```text
Smalt OCEL 2.0 JSON
       │
       ▼
SmaltBridge.ingest/1  ───>  Ex4pm.ingest/1  ───>  %Ex4pm.EventLog{}
                                                        │
                      ┌─────────────────────────────────┴─────────────────────────────────┐
                      ▼                                                                   ▼
       Ex4pm.OCEL.flatten(log, type)                                      Ex4pm.discover(log, type)
                      │                                                                   │
                      ▼                                                                   ▼
       Trace sets & activity frequencies                                  %Ex4pm.Run{value: dfg}
                      │                                                                   │
                      └─────────────────────────────────┬─────────────────────────────────┘
                                                        ▼
                                            SmaltBridge.encode_model/1
                                                        │
                                                        ▼
                                         Output JSON file with Standing Receipt
```

---

## 3. Work Completed

1. **Bridge Implementation**:
   - Authored `priv/smalt/powl_bridge.exs` with module `SmaltBridge` containing:
     - `ingest/1`: Safe file reading, JSON decoding, and `%Ex4pm.EventLog{}` ingestion with `%Ex4pm.Refusal{}` handling.
     - `flatten_per_type/1`: Enumeration and trace extraction across all unique object types.
     - `encode_model/1` & `decode_model/1`: Bidirectional translation between BEAM in-memory tuple-keyed DFGs (`{{a, b}, meta}`) and portable JSON arrays.
     - `run_standing/1`: Extracting `:standing` and `:receipt_hash`.
2. **CLI Runner Dispatch**:
   - Added `System.argv()` pattern matching for `["discover", in_path, out_path, object_type]` and `["conform", in_path, model_path, out_path, object_type]`.
   - Added human-readable and machine-parseable error messages with exit code 1 on invalid arguments or execution refusal.
3. **Packaging Inclusion**:
   - Confirmed `priv/smalt/powl_bridge.exs` is included in Hex bundle `ex4pm-26.11.10.tar`.

---

## 4. Acceptance Criteria

- [x] `priv/smalt/powl_bridge.exs` exists and is syntactically valid Elixir.
- [x] Zero external dependencies required beyond existing `ex4pm` deps (`jason`).
- [x] DFG models serialize and deserialize without loss of activities, start/end nodes, counts, or transition metrics.
- [x] `run_standing` correctly maps `:alive` and `:refused` outcomes with cryptographic subject hashes.
- [x] Packaged cleanly in Hex tarball `ex4pm-26.11.10.tar`.

---

## 5. Verification Method

1. **Syntax & CLI Help Verification**:
   ```bash
   elixir -S mix run priv/smalt/powl_bridge.exs
   ```
   *Expected Output*: Prints CLI usage banner: `usage: powl_bridge.exs discover ... | conform ...` with exit code 1.

2. **Package Verification**:
   ```bash
   mix hex.build
   tar -tf ex4pm-26.11.10.tar | grep powl_bridge.exs
   ```
   *Expected Output*: `priv/smalt/powl_bridge.exs` present in the tar archive.

---

## 6. History & Receipts

- **2026-10-17**: Initial bridge script drafted and tested with synthetic Order-to-Delivery OCEL log.
- **2026-11-10**: Verified CLI argument parser, JSON DFG serialization roundtrip, and included in v26.11.10 Hex release candidate.
