#!/usr/bin/env bash
# SUPERSEDED (2026-09-09, ERRC cluster c8) by `mix ex4pm.ggen.sync` (see
# lib/mix/tasks/ex4pm.ggen.sync.ex and priv/ggen/manifest.json, which
# declares this exact unit under the name "standing_coded"). Kept for now
# as the historical reference this session's PRD-v26.9.10.md cites; will
# be removed in a follow-up once `mix ex4pm.ggen.sync` has run in CI a few
# times. Prefer `mix ex4pm.ggen.sync` for any new work.
#
# Ex4pm.Standing.Coded -- ex4pm's own first ggen_igniter-manufactured
# module (docs/PRD-v26.9.10.md R1). Which STANDING[CODE] combinations are
# admitted is real, varying, ontology-shaped data (mirrors beam4pm's own
# bpma:AdmittedActuation/bpmi:AdmittedIngestRoute admission-fact pattern),
# so this is generated, not hand-written -- see docs/PRD-v26.9.10.md's
# "requirement classification" section for the full reasoning.
#
# Run from the ex4pm repo root. Requires {:ggen_igniter, ...} in mix.exs
# (R0, already wired).
set -euo pipefail

QUERIES="priv/ggen/queries"
TEMPLATES="priv/ggen/templates"

mix deps.get

# 1. Ex4pm.Standing.Coded: the reason-coded standing module.
mix ggen_igniter.sync \
  --ontology priv/ontology/ex4pm.ttl \
  --query admitted="$QUERIES/admitted_standing_codes.rq" \
  --template "$TEMPLATES/standing_coded.ex.eex" \
  --out lib/ex4pm/standing_coded.ex

# 2. Real round-trip test suite, one test per admitted example.
mix ggen_igniter.sync \
  --ontology priv/ontology/ex4pm.ttl \
  --query admitted="$QUERIES/admitted_standing_codes.rq" \
  --template "$TEMPLATES/standing_coded_test.exs.eex" \
  --out test/standing_coded_test.exs

# Verify.
mix compile --warnings-as-errors
mix test test/standing_coded_test.exs
