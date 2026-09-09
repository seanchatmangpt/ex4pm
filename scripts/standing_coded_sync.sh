#!/usr/bin/env bash
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
