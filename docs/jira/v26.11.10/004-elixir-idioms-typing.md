# ex4pm-004: Idiomatic Functional Elixir, Typed Refusals, and Strict Typespec Coverage

- **Standing**: VERIFIED
- **Created**: 2026-11-10 (v26.11.10 release campaign)
- **Author / Persona**: José Valim (Elixir Language Creator & Type System Architect)
- **Domain**: Functional Programming, Elixir 1.17/1.20 Idioms, Gradual Typing, Error Contracts
- **Target Files**: `lib/ex4pm/core.ex`, `lib/ex4pm.ex`, `lib/ex4pm/evidence.ex`

---

## 1. Context & Architecture

Elixir is designed around clarity, explicit data transformations, pattern matching, and predictability. In domain-heavy analytical systems, a common anti-pattern is throwing generic runtime exceptions or using ad-hoc `{:error, reason_string}` tuples that force callers into string parsing.

In `ex4pm`:
1. **Explicit Structs over Opaque Maps**: All analytical entities are first-class immutable structs (`%Ex4pm.EventLog{}`, `%Ex4pm.Run{}`, `%Ex4pm.Subject{}`, `%Ex4pm.Evidence.Receipt{}`).
2. **Typed Error Hierarchy**: Errors are never raised on invalid analytical inputs; they are returned as typed `%Ex4pm.Refusal{}` structs with deterministic machine-readable codes.
3. **Standing Lattice**: Execution confidence is modeled as a 6-state mathematical bounded lattice rather than a binary boolean.
4. **Compile-Time Type Safety**: Full `@spec` and `@type` coverage across the entire codebase, verified against Elixir 1.17 and 1.20 set-theoretic typing capabilities.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        Ex4pm Execution Paradigm                        │
│                                                                        │
│                Input Request (Log, Net, Options)                       │
│                               │                                        │
│                               ▼                                        │
│               Ex4pm.Evidence.BRCE Admission Gate                       │
│                               │                                        │
│               ┌───────────────┴───────────────┐                        │
│               ▼                               ▼                        │
│         [Authorized]                    [Refused]                      │
│               │                               │                        │
│               ▼                               ▼                        │
│       Execute Engine            {:error, %Ex4pm.Refusal{               │
│               │                    code: :unauthorized_actuation,      │
│        ┌──────┴──────┐             mode: :strict,                      │
│        ▼             ▼             missing_tokens: nil,                │
│    {:ok, %Run{}}  {:error, ...}    details: %{...}                     │
│    standing:      standing:     }}                                     │
│    :alive         :blocked                                             │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Scope & Technical Specification

### 2.1 The `%Ex4pm.Refusal{}` Specification
In `lib/ex4pm/core.ex`:
```elixir
defmodule Ex4pm.Refusal do
  @enforce_keys [:code, :message]
  defstruct [
    :code,
    :message,
    :subject,
    :mode,
    :missing_tokens,
    details: %{}
  ]

  @type t :: %__MODULE__{
          code: atom(),
          message: String.t(),
          subject: term(),
          mode: atom() | nil,
          missing_tokens: list() | nil,
          details: map()
        }
end
```
- **New in v26.11.10 (`e384dd1`)**:
  - `:mode`: Captures the execution or enforcement mode (`:strict`, `:permissive`, `:dry_run`, `:audit`).
  - `:missing_tokens`: Explicit list of unsatisfied input places in Petri net token game simulations, eliminating diagnostic guesswork.

### 2.2 Mathematical Standing Lattice (`Ex4pm.Standing`)
In `lib/ex4pm/core.ex:1-28`:
- 6-state ordered lattice:
  `:unknown < :unsupported < :build_broken < :blocked < :partial_alive < :alive`
- Supports `min/2` and `meet/2` operations over multi-engine consensus or sequential pipelines.
- Standing is always evidence-derived; no hardcoded `:alive` claims are permitted without a recorded receipt hash in `Ex4pm.Evidence.Store`.

### 2.3 Strict Typespec (`@spec`) and Dialyzer Coverage
- Every public function in `lib/ex4pm.ex` declares exhaustive `@spec`:
  - `discover(EventLog.t(), keyword()) :: {:ok, Run.t()} | {:error, Refusal.t()}`
  - `conform(EventLog.t(), term(), keyword()) :: {:ok, Run.t()} | {:error, Refusal.t()}`
  - `simulate(term(), keyword()) :: {:ok, Run.t()} | {:error, Refusal.t()}`
  - `optimize(term(), term(), keyword()) :: {:ok, Run.t()} | {:error, Refusal.t()}`
- All engine adapters implement behaviour callbacks with typed `@callback` definitions.

### 2.4 OTP 27 `:json` Hot Path
- In hot NDJSON parsing loops, `ex4pm` leverages native Erlang/OTP 27 `:json` module rather than external library dispatch, achieving zero-copy binary streaming and lower GC pressure.

---

## 3. Work Completed

1. **Refusal Struct Enhancement**:
   - Extended `%Ex4pm.Refusal{}` with `:mode` and `:missing_tokens` fields.
   - Updated call sites in `PowlExecutor`, `SoundnessProver`, and `Admission` to populate these fields.
2. **Comprehensive `@spec` Audit**:
   - Audited 100% of public module boundaries in `lib/ex4pm/` and `lib/ex4pm_engine/`.
   - Verified clean compilation with zero warnings (`mix compile --warnings-as-errors`).
3. **Data Struct Normalization**:
   - Refactored legacy raw map returns to use canonical structs (`%Ex4pm.Subject{}`, `%Ex4pm.Run{}`).

---

## 4. Acceptance Criteria

- [x] `%Ex4pm.Refusal{}` includes `:code`, `:message`, `:subject`, `:mode`, `:missing_tokens`, and `:details`.
- [x] Functions never raise on invalid data; all error paths return `{:error, %Ex4pm.Refusal{}}`.
- [x] Standing transitions strictly obey the 6-state lattice.
- [x] All public functions in `lib/ex4pm.ex` have `@spec` definitions.
- [x] `mix compile --warnings-as-errors` passes with zero compiler warnings.

---

## 5. Verification Method

1. **Compilation Gate**:
   ```bash
   mix compile --warnings-as-errors
   ```
   *Expected Output*: Exit code 0, no warnings.

2. **Refusal Struct Contract Test**:
   ```bash
   mix test test/refusal_test.exs test/core_test.exs
   ```
   *Expected Output*: Verifies field presence, default values, and JSON encoding.

---

## 6. History & Receipts

- **2026-09-15**: Standing lattice formalized in `lib/ex4pm/core.ex`.
- **2026-11-07**: Commit `e384dd1` landed `:mode` and `:missing_tokens` in `Ex4pm.Refusal`.
- **2026-11-10**: Validated typespec completeness and Elixir 1.20 set-theoretic type compatibility for v26.11.10.
