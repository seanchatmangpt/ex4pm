# ex4pm-005: Phoenix 1.7 LiveView Interactive Observability and AshAdmin UI

- **Standing**: VERIFIED
- **Created**: 2026-11-10 (v26.11.10 release campaign)
- **Author / Persona**: Chris McCord (Phoenix Framework & LiveView Creator)
- **Domain**: Real-Time Web, Phoenix 1.7, LiveView 1.0, PubSub Streaming, AshAdmin UI
- **Target Files**: `test/demo_web/lib/ex4pm_web/*`, `lib/ex4pm_domain.ex`

---

## 1. Context & Architecture

Process mining and formal process analytics are often trapped in desktop academic tools (e.g. ProM) or complex legacy enterprise portals. To demonstrate real-time process intelligence, `ex4pm` features a **Phoenix 1.7 LiveView** demo suite that streams live events, renders interactive mathematical process models, and visualizes cluster execution topology over WebSockets.

Critically, **zero web dependencies contaminate the core Hex release**:
- All web code is isolated inside `test/demo_web/`.
- Hex packaging explicitly includes only `lib/`, `priv/`, `mix.exs`, `README.md`, `CHANGELOG.md`, and `LICENSE`.
- Core consumers of `ex4pm` get pure, high-performance process intelligence without dragging in Phoenix, Cowboy, or CSS assets.

```text
                           Phoenix LiveView Browser Client
                                         │  (WebSocket)
                                         ▼
                             Ex4pmWeb.Endpoint (Plug)
                                         │
                       ┌─────────────────┴─────────────────┐
                       ▼                                   ▼
              Ex4pmWeb.Router                     Phoenix.PubSub
                       │                                   │
       ┌───────────────┼───────────────┐                   ▲
       ▼               ▼               ▼                   │
 DashboardLive   PowlMinerLive  ProcessIntelLive           │
 (Mermaid/DAG)   (Tri-View/XML) (OnlineMiner DFG)          │
       │               │               │                   │
       └───────────────┼───────────────┘                   │
                       ▼                                   │
          Ex4pm Analytical Engines                         │
         (POWL, Conformance, BRCE)                         │
                       │                                   │
                       └──────── Emit Receipts ────────────┘
```

---

## 2. Scope & Technical Specification

### 2.1 LiveView Suite (`test/demo_web/lib/ex4pm_web/live/`)
1. **`DashboardLive` (`live/dashboard_live.ex`)**:
   - Living reactor execution graphs rendered as real-time Mermaid diagrams.
   - Dynamic BEAM cluster topology visualizer (active nodes, schedulers, memory utilization).
   - Real-time PubSub receipt stream listening on `"ex4pm:evidence:receipts"`.
2. **`PowlMinerLive` (`live/powl_miner_live.ex`)**:
   - Mathematical UTF-8 operator rendering for POWL trees:
     - Strict partial order: $\prec$
     - Exclusive choice: $\oplus$
     - Loop: $\circlearrowleft$
     - Concurrency: $\wedge$
     - Silent transition: $\tau$
   - Chunked drag-and-drop file upload supporting OCEL 2.0 JSON and NDJSON up to 50MB.
   - Interactive Tri-View interface:
     - View 1: Choice & Dependency Graph
     - View 2: 1-Safe Petri Net Token Simulator
     - View 3: BPMN 2.0 Diagram
   - Instant export endpoints: BPMN 2.0 XML, PNML XML, and POWL JSON.
3. **`ProcessIntelligenceLive` (`live/process_intelligence_live.ex`)**:
   - Streaming directly-follows graph (DFG) live updates via `Ex4pm.Engine.OnlineMiner`.
   - Dynamic frequency heatmaps and variant distribution graphs.
   - Refusal telemetry audit table inspecting `%Ex4pm.Refusal{}` rejection causes.

### 2.2 AshAdmin Administrative UI
- Configured in `test/demo_web/lib/ex4pm_web/router.ex:32`:
  ```elixir
  scope "/" do
    pipe_through :browser
    ash_admin "/admin"
  end
  ```
- Exposes all 34 Ash resources declared in `Ex4pmDomain` (`lib/ex4pm_domain.ex`) with `admin do show?(true) end`.
- Administrators can inspect events, objects, receipts, and refusal telemetry directly via declarative auto-generated CRUD interfaces.

### 2.3 Streaming Infrastructure (`Phoenix.PubSub`)
- `Ex4pmWeb.Endpoint` configures `pubsub_server: Ex4pm.PubSub`.
- `Ex4pm.Evidence.BRCE` and `Ex4pm.Stream.Pipeline` broadcast state transitions:
  - `Phoenix.PubSub.broadcast(Ex4pm.PubSub, "ex4pm:evidence:receipts", {:new_receipt, receipt})`
- LiveView processes subscribe on mount and update UI state reactively without page reloads.

---

## 3. Work Completed

1. **Test Environment Isolation**:
   - Configured `test/test_helper.exs` and `mix.exs` to ensure Phoenix, LiveView, and AshAdmin are scoped strictly to `:test` and `:dev`.
   - Confirmed `mix hex.build` excludes `test/demo_web/` entirely.
2. **Interactive Tri-View Mining**:
   - Implemented POWL-to-BPMN 2.0 XML and PNML converters.
   - Tested drag-and-drop ingestion of standard BPI Challenge and synthetic OCEL logs.
3. **PubSub Telemetry Verification**:
   - Verified that BRCE actuation receipts broadcast and render within < 16ms of execution.

---

## 4. Acceptance Criteria

- [x] LiveView demo application boots under `MIX_ENV=test`.
- [x] `DashboardLive`, `PowlMinerLive`, and `ProcessIntelligenceLive` mount and render without client-side JavaScript crashes.
- [x] `ash_admin("/admin")` mounts and renders all 34 `Ex4pmDomain` resources.
- [x] POWL mathematical symbols render accurately in UTF-8.
- [x] Hex release package excludes `test/demo_web/` keeping tarball size at ~2.0MB.

---

## 5. Verification Method

1. **Test Suite Verification**:
   ```bash
   mix test test/demo_web/
   ```
   *Expected Output*: LiveView mount tests, router tests, and PubSub event handling tests pass cleanly.

2. **Package Isolation Audit**:
   ```bash
   mix hex.build
   tar -tf ex4pm-26.11.10.tar | grep -E "demo_web|test" || echo "CLEAN: Zero test/web files in package"
   ```
   *Expected Output*: Prints `CLEAN: Zero test/web files in package`.

---

## 6. History & Receipts

- **2026-09-30**: Initial LiveView prototype and PowlMinerLive tri-view designed.
- **2026-10-15**: Integrated AshAdmin 1.3 UI with full resource inspection.
- **2026-11-10**: Verified test isolation and Hex packaging cleanliness for v26.11.10.
