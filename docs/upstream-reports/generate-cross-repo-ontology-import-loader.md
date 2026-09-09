# GENERATE-CROSS-REPO-ONTOLOGY-IMPORT-LOADER (Create, upstream: ggen_igniter)

## Evidence

- `GgenIgniter.Ontology.load!/1` reads exactly one file per sync invocation with no
  `owl:imports` resolution. This is not independently re-verified against the
  `ggen_igniter` source in this run (this session's scope excludes editing/reading
  `~/ggen_igniter` and `~/ggen` beyond citation) — cited as reported by the prior
  research pass, and corroborated by the xaas-side disclosure below, which names the
  same limitation from the consuming side.

- xaas's own vendored pack discloses the limitation directly, in its own
  `rdfs:comment`:
  `~/xaas/priv/packs/xaas_ocel_envelope_pack/ontology.ttl:13`:
  > "VENDORED FRAGMENT — subset of /Users/sac/ex4pm/priv/ontology/ex4pm.ttl and
  > /Users/sac/ex4pm/priv/shacl/ex4pm-shapes.ttl, copied into this repo because
  > ggen_igniter's Ontology.load!/1 reads exactly one file per sync invocation with no
  > owl:imports resolution, and this pack's own agp:CodegenTarget pipeline individuals
  > must coexist with these Event/EventShape facts in one file. Cross-repo path
  > resolution (--ontology pointing directly at ex4pm's real file) was found to work
  > mechanically but produces a machine-specific absolute path with zero CI/portability
  > guarantee and zero drift-detection (ex4pm is an unpinned path dependency, absent
  > from mix.lock) — vendoring this ontology fact makes it visible in xaas's own git
  > history and diffable on future ex4pm changes instead."

- The same pattern recurs in a second xaas pack, `xaas_telemetry_pack`, which vendors
  ex4pm's OCEL envelope shape with only a **prose** commit-SHA pin, not an executable
  gate:
  `~/xaas/priv/packs/xaas_telemetry_pack/ontology.ttl:10`:
  > "Vendored (not a live cross-repo pointer) SHACL-style grounding of the batch
  > envelope shape required by Ex4pm.OCEL.validate_envelope/1, read field-for-field
  > from /Users/sac/ex4pm/lib/ex4pm/ocel.ex around line 366-417, at ex4pm commit
  > 725f495eb90d32a1582e6f44c08151d07743b784 (2026-09-09)."

  Verified independently in this run:
  - `ex4pm/lib/ex4pm/ocel.ex:366-417` is the real `validate_envelope/1` clause the
    comment describes (schema/producer/sequence/events field checks, `previous_digest`,
    `objects`, `object_relationships` construction) — content matches the vendored
    description field-for-field.
  - The exact commit SHA cited, `725f495eb90d32a1582e6f44c08151d07743b784`, is the real
    last-touching commit for `lib/ex4pm/ocel.ex` in this repo
    (`git log -1 --format=%H -- lib/ex4pm/ocel.ex`), confirming the prose pin is
    currently accurate — but nothing in the pipeline re-checks this pin against ex4pm's
    actual current state; it is asserted in a comment, not gated by a content hash or CI
    check.
  - Two further divergences are vendored *as-is*, not corrected, at
    `~/xaas/priv/packs/xaas_telemetry_pack/ontology.ttl:59-68` (`ocel:timestamp` typed
    as `xsd:dateTime` upstream vs. plain `String.t()` in xaas; `ocel:omap` modeled as
    per-instance object IDs upstream vs. a type-name list in xaas) — both are silent
    divergences a real `owl:imports` mechanism with hash verification would either
    reconcile or surface as an explicit conflict, rather than leaving them as
    undetected drift risk.

- This session independently reproduced the same failure mode one layer up the stack,
  by hand, rather than through tooling: the `norm/1` template convention was
  hand-copied from `beam4pm` into `ex4pm` at the template layer (not the ontology
  layer) in a prior commit on this branch (`9df2384 feat: OCEL2/OLAP core, discovery/
  conformance additions, stream sink, Chicago net-partition test`) — the same
  copy-and-manually-repin pattern the xaas packs describe, recurring without any
  `ggen_igniter`-level fix in between. This is offered as a second, independently
  observed instance of the same root cause (no executable cross-repo import/pin
  mechanism), not as a citation to a specific upstream file.

## Recommendation

Add real `owl:imports` resolution to `GgenIgniter.Ontology.load!/1`:

1. Resolve `owl:imports <IRI-or-path>` statements found in a loaded ontology file by
   fetching/reading the referenced ontology (local path or URL) and merging its
   triples into the load, rather than requiring every consuming pack to hand-copy
   facts into one file.
2. Verify a content hash of the imported ontology against a pinned hash recorded in
   the importing pack (replacing the current prose-only SHA comment pattern seen at
   `~/xaas/priv/packs/xaas_telemetry_pack/ontology.ttl:10`) — a hash mismatch should
   fail the sync loudly, not silently re-vendor stale facts.
3. Until (1)-(2) land, treat every existing vendored-fragment pack (both xaas packs
   above, and the ex4pm `norm/1` template copy noted here) as `PARTIAL_ALIVE`: the
   vendored copy is real and currently accurate, but it is drift-unprotected — nothing
   re-verifies it against its upstream source on an ongoing basis.

## Filed

- Date: 2026-09-09
- Repo: `/Users/sac/ex4pm` (branch `docs/xaas-integration-roadmap`)
- Claude-Session: https://claude.ai/code/session_01XWhXfubgh1b1rFNNStAQot
