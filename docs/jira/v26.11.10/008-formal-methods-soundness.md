# ex4pm-008: Formal Methods, 1-Safety Token Game, and State-Machine Soundness Prover

- **Standing**: VERIFIED
- **Created**: 2026-11-10 (v26.11.10 release campaign)
- **Author / Persona**: Leslie Lamport (TLA+ Creator & Distributed Systems / Formal Methods Turing Laureate)
- **Domain**: Formal Specification, Temporal Logic, Petri Net Invariants, State-Space Exploration, 1-Safety
- **Target Files**: `lib/ex4pm_engine/workflow_net.ex`, `lib/ex4pm_engine/ocpn/soundness_engine.ex`, `lib/ex4pm/runtime/powl_executor.ex`

---

## 1. Context & Architecture

"Writing is the nature's way of letting you know how sloppy your thinking is." In concurrent and distributed systems, empirical testing (e.g. unit testing a handful of execution paths) can never prove the absence of deadlocks, race conditions, or state corruption. A rigorous workflow or process engine must define its semantics formally and prove mathematical invariants across its complete reachable state space.

In `ex4pm`:
1. **Classical Workflow Net Soundness**: Formally models workflows as Petri nets $W = (P, T, F, i, o)$ and computes exact reachability graphs to prove proper completion, no dead transitions, and no token leaks.
2. **1-Safety Token Game**: Enforces that for all reachable markings $M$, no place ever accumulates more than one token ($M(p) \le 1$).
3. **Adversarial Mutation Courts**: Uses automated sabotage engines to mutate nets and prove that every class of temporal or structural corruption is detected and refused.

```text
                               Workflow Net W = (P, T, F, i, o)
                                              │
                                              ▼
                         Ex4pmEngine.SoundnessProver.verify/1
                                              │
                     Construct Complete Reachable State Space R(M_0)
                                              │
         ┌───────────────────┬────────────────┼───────────────────┐
         ▼                   ▼                ▼                   ▼
  Proper Completion   Clean Termination    No Dead Transitions   1-Safety Check
  M_o reachable       Only [o] marked      Every t ∈ T fireable  ∀p: M(p) ≤ 1
         │                   │                │                   │
         └───────────────────┴────────────────┼───────────────────┘
                                              ▼
                                   Soundness Report
                          sound?: boolean, invariants: map()
```

---

## 2. Scope & Technical Specification

### 2.1 The 4 Classical Soundness Invariants
Implemented in `lib/ex4pm_engine/workflow_net.ex` and `lib/ex4pm_engine/ocpn/soundness_engine.ex`:
1. **Proper Completion**: From the initial marking $M_i = [i]$, there exists a firing sequence $\sigma$ such that $M_i \xrightarrow{\sigma} M_o = [o]$.
2. **Clean Termination**: For any reachable marking $M \in R(M_i)$, if $M \ge [o]$, then $M = [o]$. That is, when the output place receives a token, no tokens remain trapped in intermediate places.
3. **No Dead Transitions (Liveness)**: For every transition $t \in T$, there exists at least one reachable marking $M \in R(M_i)$ such that $M \xrightarrow{t}$. No code or process branch is unreachable dead code.
4. **Boundedness / 1-Safety**: The net is 1-safe; no reachable marking has $M(p) > 1$. Prevents memory leaks and multiple-instance execution race conditions.

### 2.2 Token Game State Machine (`PowlExecutor`)
In `lib/ex4pm/runtime/powl_executor.ex`:
- Implements the formal firing rule:
  $$\forall p \in \bullet t: M(p) \ge W(p, t)$$
- Firing transition $t$ yields next marking:
  $$M'(p) = M(p) - W(p, t) + W(t, p)$$
- If firing $t$ would result in $M'(p) > 1$ in a 1-safe model, the state machine refuses transition with `%Ex4pm.Refusal{code: :unsafe_token_overflow}`.
- If tokens are missing from $\bullet t$, refuses transition with `%Ex4pm.Refusal{code: :insufficient_tokens, missing_tokens: missing_places}`.

### 2.3 The Sabotage Adversarial Court
In `lib/mix/tasks/ex4pm.qualification.ex:21-57`:
- Applies 6 deterministic structural and temporal mutations:
  1. `:extra_trace` - Injecting out-of-order traces into a conforming log.
  2. `:missing_trace` - Truncating required terminal traces.
  3. `:wrong_order` - Inverting causal arcs in the reachability graph.
  4. `:duplicate_execution` - Firing a non-loop transition multiple times.
  5. `:lost_terminal` - Dropping tokens before the terminal sink place $[o]$.
  6. `:wrong_bound` - Violating the 1-safe place upper bound.
- **Court Law**: The court asserts that 100% of mutations are detected and rejected. If a single mutation passes verification without refusal, the court fails with `:vacuous_verification_failure`.

---

## 3. Work Completed

1. **State-Space Reachability BFS**:
   - Implemented breadth-first search exploration of Petri net state markings with cycle detection.
   - Bounded state space exploration to prevent infinite loops in cyclic nets.
2. **Compile-Time Spark Integration**:
   - Wired `VerifySoundness` into Ash resources so that unsound business state machines fail during compilation.
3. **Sabotage Gate Verification**:
   - Confirmed zero mutations survive detection under `mix ex4pm.sabotage.court`.

---

## 4. Acceptance Criteria

- [x] `Ex4pmEngine.SoundnessProver` correctly verifies Proper Completion, Clean Termination, Liveness, and 1-Safety.
- [x] State space exploration terminates deterministically on arbitrary bounded workflow nets.
- [x] `PowlExecutor` detects and refuses token underflow and 1-safety overflow.
- [x] `mix ex4pm.sabotage.court` detects all 6 mutation classes with zero false negatives.
- [x] Compile-time checks prevent deployment of deadlocking state machines.

---

## 5. Verification Method

1. **Sabotage Adversarial Court**:
   ```bash
   mix ex4pm.sabotage.court
   ```
   *Expected Output*: Executes 6 mutation vectors, confirms all mutations detected, and exits with code 0.

2. **Soundness Engine Property Tests**:
   ```bash
   mix test test/workflow_net_test.exs test/soundness_engine_test.exs
   ```
   *Expected Output*: Proves reachability graph correctness and invariant checks against known sound and unsound nets.

---

## 6. History & Receipts

- **2026-09-24**: Formal 1-safety token game implemented in `PowlExecutor`.
- **2026-10-12**: Sabotage mutation court added to verification pipeline.
- **2026-11-10**: Verified complete invariant enforcement for v26.11.10.
