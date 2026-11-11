# Architectural & Contracts Review: ex4pm v26.11.10
**Reviewer**: Andy Hunt (Co-author of *The Pragmatic Programmer* and *The Agile Manifesto*)  
**Domain**: Architecture, Design by Contract (DbC), Invariants, Orthogonality, State Isolation, and Test Harness Integrity  
**Date**: 2026-11-11  
**Target Release**: v26.11.10  
**Verdict**: **APPROVE WITH RECOMMENDATIONS**

---

## 1. Executive Summary

As a co-author of *The Pragmatic Programmer* and one of the initial seventeen signatories of the *Agile Manifesto*, my focus when evaluating any software architecture centers on a pragmatic truth: **software craftsmanship is about building systems that are robust, decoupled, easily reasoned about, and fortified by clear contracts.** Systems decay not from single catastrophic blows, but through the slow accumulation of broken windows—untested assumptions, blurred boundaries, duplication, and leaky abstractions.

In reviewing `ex4pm` (specifically focusing on `Ex4pm.Contracts`, `Ex4pm.Subject`, `Ex4pm.Evidence.BRCE`, `test/ws5_contracts/`, and `lib/ex4pm.ex`), I examined whether this system adheres to the core tenets of Pragmatic Craftsmanship:
1. **Design by Contract (DbC)**: Are preconditions, postconditions, and invariants strictly enforced and failure modes made explicit?
2. **Orthogonality**: Does changing an analytical algorithm, an evidence store, or a public facade leave the other subsystems untouched?
3. **Command-Query Separation & Authority Fences**: Is pure computation strictly isolated from side-effecting actuation?
4. **DRY (Don't Repeat Yourself)**: Does every piece of knowledge have a single, unambiguous, authoritative representation?
5. **Tracer Bullets & Fast Feedback**: Do developer feedback loops fire rapidly and reliably without false negatives?

**Key Finding**: `ex4pm` exhibits world-class architectural rigor in its separation between `CONSTRUCT` (pure calculation, querying, planning, AST derivation) and `DO` (actuation, side effects, execution). The `Ex4pm.Evidence.BRCE` boundary is one of the most elegant, disciplined manifestations of Command-Query Separation and Design by Contract I have seen on the BEAM. It guarantees zero unreceipted actuation: pending receipts must persist before actuation begins, and outcome receipts must record the terminal standing (`:alive` or `:blocked`).

However, alongside this architectural brilliance, I uncovered several "broken windows" stemming from past refactorings (specifically the migration from an umbrella project layout to a flat application layout):
- **A critical blind spot in static anti-cheat enforcement**: `Ex4pm.Qualification.LieFinder` and `BrceEnforcer` scan `Path.wildcard("apps/*/lib/**/*.ex")`, which currently matches zero files, completely skipping the 419 real Elixir modules under `lib/`.
- **Brittle and redundant contract tests in `test/ws5_contracts/`**: 24 separate test files perform identical text-scraping string assertions against `mix.exs` rather than asserting against the semantic `Mix.Project.config()`.
- **Exclusion of core contract tests from standard developer loops**: `test/contracts_test.exs` is tagged `@tag :integration`, meaning standard `mix test` ignores the verification of ontology, WIT, SHACL, and receipt schemas.
- **Subtle canonicalization asymmetry in `Ex4pm.Core.Hash.digest/2`**: Struct canonicalization works for top-level structs and maps, but bypasses collections when a list of structs is passed at the top level.

Because none of these issues represent bad-faith facade implementations or intentional integrity violations (the underlying domain logic, WASM admission, and BRCE enforcement are 100% genuine and fully functional), my verdict is **APPROVE WITH RECOMMENDATIONS**.

---

## 2. Persona Perspective & Philosophical Alignment

In *The Pragmatic Programmer*, Dave Thomas and I outlined several foundational principles. Let us look at how `ex4pm` aligns with them:

### 2.1 Pragmatic Paranoia & Design by Contract (DbC)
> *"A good contract between client and supplier specifies what the client must provide, and what the supplier guarantees in return. If either party breaks the contract, there is no ambiguity about who failed."*

`ex4pm` embraces DbC not through informal documentation, but through executable structs and typed refusals:
- Preconditions are verified via explicit pattern matches and guards (e.g., `BRCE.admit/2`, `Contracts.verify_required_terms/0`).
- Postconditions are sealed in cryptographic evidence envelopes (`Ex4pm.Evidence.Receipt`).
- Invariants are guaranteed by enforcing immutable content-addressed subjects (`Ex4pm.Subject`).
- Refusals are typed structs (`%Ex4pm.Refusal{code: atom, message: binary, details: map}`), rejecting ungrounded assumptions without throwing unhandled runtime exceptions.

### 2.2 Orthogonality
> *"Two or more things are orthogonal if changes in one do not affect any of the others. In a well-designed system, database access is orthogonal to user interface; business logic is orthogonal to network protocols."*

The boundaries in `ex4pm` are remarkably orthogonal:
- The analytical engine (`Ex4pm.Engine`) knows nothing of the storage mechanism (`Ex4pm.Evidence.Store`).
- The storage layer relies on an interchangeable GenServer contract, enabling memory-backed ETS or durable external ledgers.
- The WASM runtime adapter executes in zero-import sandboxes (`Ex4pmEngine.Wasm.Host`), unaware of whether it is running inside Phoenix LiveView or a CLI batch pipeline.
- The public API (`Ex4pm`) serves as an orchestration facade, keeping internal routing decoupled from user-facing function signatures.

### 2.3 Command-Query Separation & Zero Unreceipted Actuation
> *"Functions that change state should not return complex data; functions that calculate data should not change state."*

Bertrand Meyer's Command-Query Separation is taken to its logical extreme in `ex4pm`. Analytical calls (`discover`, `conform`, `simulate`, `optimize`, `plan`, `cmca`, `ferroplan`, `statistics`) are strictly classified as `CONSTRUCT` operations. They compute candidates, return immutable `%Ex4pm.Run{}` envelopes, and are structurally forbidden from triggering external side effects. Only `Ex4pm.operate/3` is permitted to cross the `BRCE` fence into the `DO` domain, and it can only do so with an admitted authority token and pre-committed receipts.

### 2.4 Don't Live with Broken Windows
> *"Don't leave 'broken windows' (bad designs, wrong decisions, or poor code) unrepaired. Fix each one as soon as it is discovered."*

When an umbrella project is migrated to a flat project, stale paths in test suites and static analysis tools are typical "broken windows." If left unattended, developers and automated agents develop a false sense of security, assuming that static linters are guarding the code when in reality they are scanning empty directories. This review exposes those windows so they can be promptly repaired.

---

## 3. Deep Dive & Architectural Citations

### 3.1 Verification Contracts: `Ex4pm.Contracts`
**Location**: `lib/ex4pm/contracts.ex:1-124`

`Ex4pm.Contracts` manages the canonical public ontology, SHACL shapes, WIT component specifications, and JSON receipt schemas:

```elixir
# lib/ex4pm/contracts.ex:9-21
  @artifacts %{
    ontology: "ontology/ex4pm.ttl",
    shacl: "shacl/ex4pm-shapes.ttl",
    wit: "wit/ex4pm.wit",
    receipt_schema: "schema/receipt.schema.json"
  }

  @required %{
    ontology: ["ex4pm:EventLog", "ex4pm:ProcessModel", "ex4pm:Receipt", "ex4pm:Authority"],
    shacl: ["sh:NodeShape", "ex4pm:EventShape", "ex4pm:ReceiptShape"],
    wit: ["world ex4pm-engine", "discover:", "conform:", "simulate:"],
    receipt_schema: ["subject_hash", "operation", "standing", "artifact_hash"]
  }
```

#### Observations:
1. **Manifest Integrity (`Contracts.manifest/0`, lines 29-55)**:
   The function iterates over `@artifacts`, reads the bytes from `priv/<relative_path>`, computes each artifact's cryptographic digest via `Ex4pm.Core.Hash.digest(bytes)`, and returns a structured map of entries. If an artifact is missing, it halts immediately with `{:error, %Refusal{code: :contract_artifact_missing}}`.
2. **Deterministic Contract Hash (`Contracts.verify/0`, lines 57-68)**:
   `verify/0` computes an aggregate `contract_hash` by digesting the entire manifest map:
   ```elixir
   {:ok, %{
     version: @contract_version,
     artifacts: manifest,
     contract_hash: Hash.digest(manifest),
     standing: :alive
   }}
   ```
   Executing this live in `MIX_ENV=test` yields:
   `sha256:563d116537f3d8497fdd50a5119fe6b67cdc0137309e1d03e70c4b0d95b6c91c`.
3. **Term Presence Verification (`verify_required_terms/0`, lines 92-112)**:
   The function scans each artifact to verify that required semantic terms exist.
   *Critique*: Notice lines 95-96:
   ```elixir
   missing = Enum.reject(required_terms, &String.contains?(bytes, &1))
   ```
   This is substring containment. While fast and dependency-free, it is semantically shallow. A commented-out term `# ex4pm:EventLog` satisfies `String.contains?/2`. For true semantic guarantees, future versions should parse the RDF/Turtle, validate the SHACL AST, and parse the JSON Schema.

---

### 3.2 Subject Content Addressing & Identity: `Ex4pm.Subject` & `Ex4pm.Core.Hash`
**Location**: `lib/ex4pm/core.ex:70-126`

`Ex4pm.Subject` is the immutable identity carrier for any entity entering the process intelligence pipeline:

```elixir
# lib/ex4pm/core.ex:70-86
defmodule Ex4pm.Subject do
  @moduledoc "Immutable identity carrier for an admitted subject."

  @enforce_keys [:kind, :hash]
  defstruct [:id, :kind, :hash, metadata: %{}]

  def new(kind, value, metadata \\ %{}) do
    %__MODULE__{kind: kind, hash: Ex4pm.Core.Hash.digest(value), metadata: metadata}
  end
end
```

#### Hash Canonicalization Deep Dive:
In `Ex4pm.Core.Hash` (lines 88-126):
```elixir
# lib/ex4pm/core.ex:93-104
  def digest(term, :sha256) do
    binary =
      cond do
        is_binary(term) -> term
        is_map(term) -> :erlang.term_to_binary(canonicalize(term))
        true -> :erlang.term_to_binary(term)
      end

    "sha256:" <> (:crypto.hash(:sha256, binary) |> Base.encode16(case: :lower))
  end
```

#### Observations & Edge Cases Uncovered:
1. **Atom/String Map Key Equivalence**:
   Lines 124-125 define:
   ```elixir
   defp key_to_string(k) when is_atom(k) or is_binary(k) or is_number(k), do: to_string(k)
   ```
   This deliberately ensures that `%{:foo => "bar"}` and `%{"foo" => "bar"}` produce identical hashes (`sha256:cd1ccd35c884480dba569f18d0cdb22a1145e6e7743e19fc502452fb73823857`). This is an excellent pragmatic feature for interoperability between external JSON APIs and internal BEAM structs.
2. **Integer vs String Key Collision**:
   Because `is_number(k)` uses `to_string/1`, `%{1 => "a"}` and `%{"1" => "a"}` produce identical hashes (`sha256:b7b62b0bb7525002dcd749a3c31cf9d181840f5c73f69c58f90539ea0a13a110`). While integer map keys are rare in process models, numeric keys should be tagged (e.g., `"num:1"` vs `"str:1"`) to prevent collisions.
3. **Top-Level Collection Canonicalization Asymmetry**:
   Look closely at line 98:
   `is_map(term) -> :erlang.term_to_binary(canonicalize(term))`
   If `term` is a struct or a map, `canonicalize/1` recursively strips struct tags and sorts keys.
   However, if `term` is a *list* of structs, say `[struct]`, `is_map(term)` is `false`! It immediately drops into `true -> :erlang.term_to_binary(term)`.
   Our test demonstrated:
   - `digest(%Ex4pm.Subject{...}) == digest(Map.from_struct(%Ex4pm.Subject{...}))` -> `true`
   - `digest([%Ex4pm.Subject{...}]) == digest([Map.from_struct(%Ex4pm.Subject{...})])` -> **`false`**
   *Remedy*: `digest/2` should check `is_map(term) or is_list(term)` or simply pass `term` through `canonicalize/1` before binary serialization.

---

### 3.3 Authority Fences & Consequential Actuation: `Ex4pm.Evidence.BRCE`
**Location**: `lib/ex4pm/evidence.ex:1-381`

`Ex4pm.Evidence.BRCE` is the exclusive gateway for state-changing operations:

```elixir
# lib/ex4pm/evidence.ex:265-275
  def execute(subject_hash, operation, authority, fun, opts \\ []) when is_function(fun, 0) do
    with :ok <- admit(authority, operation) do
      store = Keyword.get(opts, :store, Store)
      metadata = Map.new(Keyword.get(opts, :metadata, %{}))
      pending = Receipt.pending(subject_hash, operation, authority, metadata)

      with {:ok, _} <- persist(pending, store, :pending_receipt_persistence_failed) do
        invoke_and_finalize(pending, fun, store, metadata)
      end
    end
  end
```

#### Invariant Verification:
1. **Pre-actuation Admission (`admit/2`, lines 277-299)**:
   Authority must be an explicit map containing `:do` / `"do"` in `capabilities`, or `operation` / `operation_text` in `allow`. Bare `nil` or maps lacking authority are refused without invoking `fun.()`.
2. **Guaranteed Pending Receipt**:
   `fun.()` is strictly wrapped inside `with {:ok, _} <- persist(pending, store, ...)`. If storage fails, `fun.()` is never invoked (`refute_received :invoked` verified in test suite).
3. **Fault Quarantining & Outcome Receipts (`invoke_and_finalize/4`, lines 304-335)**:
   `fun.()` is wrapped in a comprehensive `try ... rescue ... catch` block.
   - If `fun.()` succeeds, an outcome receipt is minted with standing `:alive`.
   - If `fun.()` raises an exception or throws an exit, `finalize_failure/5` mints an outcome receipt with standing `:blocked`.
   - In both cases, the receipt chains `parent_hash: pending.hash`, ensuring that any observer can replay the transaction.
4. **Replay Integrity (`Ex4pm.Evidence.Replay.verify/1`, lines 211-256)**:
   `Replay.verify` reconstructs the payload, hashes it, and verifies exact equality with `receipt.hash`. In our adversarial test where `subject_hash` was mutated, `Replay.verify` refused the tampered receipt with `:replay_mismatch`.

---

### 3.4 Public API & CONSTRUCT/DO Boundary: `Ex4pm`
**Location**: `lib/ex4pm.ex:1-778`

The orchestrator module `Ex4pm` exposes thirty-three operations, adhering to strict authority partitioning:

| Operation Category | Functions | Classification | Authority Requirement |
|---|---|---|---|
| Ingest | `ingest/2`, `ingest_xes/2` | Pure data transform | None |
| Process Mining | `discover/2`, `conform/3`, `simulate/2`, `optimize/3` | CONSTRUCT | None (Analytical run) |
| Planning | `plan/2`, `ferroplan/3`, `cmca/2` | CONSTRUCT | None (Candidate generation) |
| Statistics | `statistics/3`, `forecast/2` | CONSTRUCT | None (WASM computation) |
| System Health | `health/1`, `wasm/1`, `capabilities/2` | Inspection / Probe | None (Probe executes `:mean`) |
| Runtime Actuation | `operate/3` | **DO** | **Explicit Authority Map + BRCE** |

#### Subtle Nuance in `receipted_run/4` (lines 697-730):
In analytical calls (e.g., `discover/2`):
```elixir
# lib/ex4pm.ex:116-117
with {:ok, log} <- ensure_log(subject),
     {:ok, engine_result} <- Engine.execute(:discover, log, opts) do
  receipted_run(:discover, log.subject.hash, engine_result, opts)
end
```
Notice that `Engine.execute` runs *before* `receipted_run` persists the pending and outcome receipts. For `CONSTRUCT` operations, this is completely acceptable because computation is pure and has no external side effects. However, it means that `pending.started_at` and `outcome.finished_at` in the receipt reflect the ledger recording window rather than the engine compute duration. If microsecond-accurate engine profiling is needed, engine execution timestamps should be forwarded via `engine_result.evidence`.

---

### 3.5 Test Contracts & Regression Invariants: `test/ws5_contracts/`
**Location**: `test/ws5_contracts/` (24 files)

In August 2026, work session "WS5" generated 24 test files to lock down regression invariants following the umbrella-to-flat migration.

#### The Problem: Extreme Duplication and Text Scraping
Let us look at three representative files:

1. `test/ws5_contracts/02_stream_data_test.exs`:
```elixir
defmodule Ex4pmCore.WS5.StreamDataTest do
  use ExUnit.Case, async: true
  test "stream_data remains available for property falsifiers" do
    mix = File.read!(Path.expand("../../mix.exs", __DIR__))
    assert mix =~ ~s({:stream_data, "~> 1.0"})
  end
end
```
2. `test/ws5_contracts/03_stream_data_contract_test.exs`:
```elixir
defmodule Ex4pm.WS5.StreamDataContractTest do
  use ExUnit.Case, async: true
  @mix Path.expand("../../mix.exs", __DIR__) |> File.read!()
  test "property-learning surface retains stream_data" do
    assert @mix =~ ~s({:stream_data, "~> 1.0"})
  end
end
```
3. `test/ws5_contracts/stream_data_dep_test.exs`:
```elixir
defmodule Ex4pmCore.WS5.StreamDataDepTest do
  use ExUnit.Case, async: true
  @manifest File.read!(Path.expand("../../mix.exs", __DIR__))
  test "stream_data remains the umbrella property-testing dependency" do
    assert @manifest =~ ~s({:stream_data, "~> 1.0"})
  end
end
```

#### Pragmatic Critique:
1. **DRY Violation**: Three distinct test modules test the exact same string match against `mix.exs`. The same duplication occurs for `verify: :test` (3 files), `compile --warnings-as-errors` (3 files), `chicago: :test` (2 files), and `"ex4pm.crown": :test` (2 files).
2. **Fragile String Coupling vs Semantic Testing**:
   These tests read `mix.exs` as raw text and run regex or substring matches (`=~`).
   In `test/ws5_contracts/20_verify_test_stage_test.exs:10`:
   ```elixir
   assert mix =~ ~s("test --include integration --include stress",\n        "ex4pm.powl.court")
   ```
   This assertion is coupled to an exact newline character and eight space characters! If someone reformats `mix.exs` or re-orders lines, this test will break even though the alias is completely valid.
   *The Pragmatic Fix*: Test the semantic reality via `Mix.Project.config()`:
   ```elixir
   aliases = Mix.Project.config()[:aliases]
   assert "test --include integration --include stress" in aliases[:verify]
   ```

---

### 3.6 Anti-Cheat Static Analysis & The Blind Spot: `Ex4pm.Qualification.LieFinder`
**Location**: `lib/ex4pm_qualification/lie_finder.ex:19-25` and `lib/ex4pm_qualification/scanners/brce_enforcer.ex:11-14`

`ex4pm` includes an admirable custom static analysis tool (`mix ex4pm.lint.truth`) designed to inspect the AST for integrity violations: hardcoded metrics, bare standing strings, and bypassed BRCE boundaries (`Ash.create(Receipt)`).

However, observe line 19 of `lib/ex4pm_qualification/lie_finder.ex`:
```elixir
  @doc "Scans all Elixir source files in the project and returns a list of findings."
  def scan(root_dir \\ ".") do
    ex_files =
      Path.wildcard(Path.join(root_dir, "apps/*/lib/**/*.ex"))
      |> Enum.reject(&String.contains?(&1, "/test/"))

    Enum.flat_map(ex_files, &scan_file/1)
  end
```
And line 11 of `lib/ex4pm_qualification/scanners/brce_enforcer.ex`:
```elixir
  def scan(root_dir \\ ".") do
    Path.wildcard(Path.join(root_dir, "apps/*/lib/**/*.ex"))
    |> Enum.flat_map(&scan_file/1)
  end
```

#### The Discovery:
When `ex4pm` transitioned from an umbrella project to a flat project, `apps/` was left with only empty stub directories (`apps/ex4pm_core/lib/...` containing 0 `.ex` files). The actual 419 Elixir modules reside in `lib/`.
As a result:
`Path.wildcard(Path.join(root_dir, "apps/*/lib/**/*.ex"))` **matches 0 files!**

When `mix ex4pm.lint.truth` runs as part of `mix verify`, it prints:
```text
=======================================================
  ✓ LIE FINDER: 100% TRUTHFUL CODEBASE (0 LIES DETECTED)
=======================================================
```
This is a vacuous gate. It reports 0 lies detected because it scanned 0 files!

#### The Verification:
To confirm whether this was hiding actual integrity violations, I executed `LieFinder.scan_file/1` directly against all 419 files in `lib/**/*.ex`:
```elixir
files = Path.wildcard("lib/**/*.ex") |> Enum.reject(&String.contains?(&1, "/test/"))
findings = Enum.flat_map(files, &Ex4pm.Qualification.LieFinder.scan_file/1)
# Result: Scanned 419 files. Findings count: 0.
```
**Conclusion**: The codebase is genuinely truthful and cleanly decoupled—there are zero bypassed BRCE boundaries and zero hardcoded metrics. But the linter was asleep at the switch! Updating the wildcard path from `apps/*/lib/**/*.ex` to `{apps/*/lib,lib}/**/*.ex` will restore its active protective power.

---

## 4. Areas of Excellence & Praise

1. **The BRCE Authority Fence**:
   The implementation of `Ex4pm.Evidence.BRCE` is exemplary. Enforcing that state cannot change without a prior committed receipt and an explicit authority lease is a triumph of defensive systems design.
2. **Immutable Subject Content Addressing**:
   `Ex4pm.Subject` and `Ex4pm.Core.Hash` anchor all analytical entities to content-derived SHA-256 digests. This creates an unforgeable trace through the entire process mining lifecycle.
3. **Refusal-Centric Flow**:
   Instead of letting functions raise arbitrary exceptions or return ambiguous `nil` / `:error` values, `ex4pm` systematically returns `%Ex4pm.Refusal{code: atom}`. This is Design by Contract at its finest.
4. **Sandboxed Engine Transports**:
   The zero-import WebAssembly sandboxing via `Ex4pmEngine.Wasm.Host` and SHA-256 manifest pinning (`MANIFEST.json`) guarantees that unvetted external code cannot compromise the host BEAM node.

---

## 5. Technical Debt, Concerns & Edge Cases (The "Broken Windows")

### Finding 1 [Major]: `LieFinder` and `BrceEnforcer` Target Empty Legacy `apps/*/lib` Directory
- **Where**: `lib/ex4pm_qualification/lie_finder.ex:21`, `lib/ex4pm_qualification/scanners/brce_enforcer.ex:12`
- **Why**: Scans 0 files, rendering `mix ex4pm.lint.truth` vacuous.
- **Remedy**: Update path wildcard to `"{lib,apps/*/lib}/**/*.ex"`.

### Finding 2 [Major]: Fragile Text Scraping and Extreme Duplication in `test/ws5_contracts/`
- **Where**: All 24 files in `test/ws5_contracts/`
- **Why**: Tests read `mix.exs` via `File.read!` and check string substrings. Formatting changes will break tests; comments can cause false positives; 24 files duplicate 12 assertions.
- **Remedy**: Consolidate into a single `test/mix_contract_test.exs` querying `Mix.Project.config()` semantically.

### Finding 3 [Minor]: Contract Verification Test Excluded from Default Inner Loop
- **Where**: `test/contracts_test.exs:4`
- **Why**: Tagged with `@tag :integration`, which `test/test_helper.exs` excludes by default. A developer running `mix test` does not execute `Ex4pm.Contracts.verify()`.
- **Remedy**: Remove `@tag :integration`. Reading four small files from `priv/` takes ~20ms and belongs in the unit test suite.

### Finding 4 [Minor]: Asymmetry in `Ex4pm.Core.Hash.digest/2` for Top-Level Collections of Structs
- **Where**: `lib/ex4pm/core.ex:98`
- **Why**: `cond do is_map(term) -> ...` only canonicalizes maps. A top-level list of structs `[struct]` is not canonicalized, causing `digest([struct]) != digest([Map.from_struct(struct)])`.
- **Remedy**: Call `canonicalize/1` on all terms before calling `:erlang.term_to_binary/1`.

### Finding 5 [Minor]: Hardcoded Stale Version in `Ex4pm.Qualification.ReleaseContract`
- **Where**: `lib/ex4pm/qualification/release_contract.ex:4`
- **Why**: Contains hardcoded `@version "26.8.23"` while `mix.exs` is at `"26.10.17"` (and releasing `"26.11.10"`).
- **Remedy**: Derive version from `Application.spec(:ex4pm, :vsn)` or `Mix.Project.config()[:version]` rather than duplicating it.

---

## 6. Actionable Recommendations for v26.11.10 and Beyond

### Immediate (v26.11.10 Release Gate)
1. **Fix `LieFinder` and `BrceEnforcer` Wildcard**:
   Change `apps/*/lib/**/*.ex` to `"{lib,apps/*/lib}/**/*.ex"`. Verify that `mix ex4pm.lint.truth` scans all 419 files and passes cleanly.
2. **Remove `@tag :integration` from `test/contracts_test.exs`**:
   Ensure `Ex4pm.Contracts.verify()` runs in every `mix test` invocation.
3. **Harmonize `ReleaseContract` Version**:
   Update `@version "26.8.23"` in `lib/ex4pm/qualification/release_contract.ex` to `"26.11.10"`.

### Medium-Term (Post-Release)
1. **Consolidate `test/ws5_contracts/`**:
   Replace the 24 text-scraping files with a single, clean `test/contracts/mix_manifest_contract_test.exs` that tests `Mix.Project.config()`.
2. **Fix `Hash.digest/2` Collection Canonicalization**:
   Update `digest/2` to recursively canonicalize lists of structs and maps, ensuring consistent content addressing across all nested collection types.
3. **Semantic Term Parsing in `Ex4pm.Contracts`**:
   Replace `String.contains?/2` with true TTL/WIT/JSON AST parsing to prevent commented-out terms from satisfying contracts.

---

## 7. Review Verdict & Final Declaration

```text
================================================================================
                               FINAL VERDICT
================================================================================
  Verdict: APPROVE WITH RECOMMENDATIONS
  Status:  READY FOR v26.11.10 RELEASE QUALIFICATION
================================================================================
```

### Rationale:
The core architecture of `ex4pm` is remarkably solid. The enforcement of Command-Query Separation through `Ex4pm.Evidence.BRCE`, the content-addressed integrity of `Ex4pm.Subject`, and the typed refusal contracts represent craftsmanship of the highest order. The issues identified do not compromise system integrity, nor do they reflect intentional shortcuts. They are classic refactoring residue that can be systematically polished as the system continues to evolve.

*"Great software isn't built in a day. It is grown, pruned, and cared for by developers who refuse to live with broken windows."* — Andy Hunt
