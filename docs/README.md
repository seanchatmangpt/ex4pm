# docs/

Documentation index for ex4pm.

## Layout

- `diataxis/` — current user documentation, organized per the Diátaxis
  framework (`tutorials/`, `how-to-guides/`, `reference/`, `explanation/`).
  Start here.
- `archive/` — superseded historical documents: prior-release ARDs, PRDs and
  requirements, closed `jira/v26.9.*` wave directories, and the diverged
  `archive/consumer/` docs tree (an earlier Diátaxis draft; superseded by
  `diataxis/`).
- `guides/`, `explanation/`, `reference/` — topical documents not yet folded
  into `diataxis/`.
- `diataxis/explanation/boundary-and-authority-law.md` — the
  KNOWN != PROJECTED != AVAILABLE != ADMITTED != ALIVE != AUTHORIZED != DO
  authority chain as implemented in the core engine (receipted-but-authority-less
  analytical runs, `operate/3` as the only DO path, ferroplan as a no-DO
  planning law); the Ash-layer variant lives in `~/ash_ex4pm`.
- `sjira/`, `thesis/`, `upstream-reports/` — semantic-jira records, design
  thesis, and cross-repo port reports.

## Historical documents

Files in `archive/` and pre-v26.10 top-level documents are historical and may
describe removed subsystems (e.g. beam4pm knowledge was removed from ex4pm per
2fd3a21). They are retained for provenance, not as current guidance.

## Family (external sibling repositories)

The ex4pm process-mining family — these are sibling checkouts, not
dependencies of ex4pm:

- `~/ash_ex4pm` — `docs/diataxis/index.md` — the Ash projection layer
  wrapping this engine (pins `{:ex4pm, "== 26.10.1"}` in its `mix.exs`).
- `~/beam4pm` — `docs/diataxis/` — the OCEL engine and evidence emitter
  that consumes ex4pm's `Ex4pm.Stream.Ingest` / BRCE runtime via
  `ash_ex4pm`.
- `wasm4pm` — `docs/` — the WASM runtime for ex4pm analysis artifacts
  (see also the historical ARD in `archive/`).
