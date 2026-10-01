#!/usr/bin/env bash
# falsify-wasm-e2e.sh -- end-to-end falsifier for the ex4pm <-> wasm4pm-ex4pm-bindings WASM path.
#
#   regen (ggen pack) -> stage wasm4pm copy -> build wasm32 -> real Wasmex tests
#
# Canonical checkouts are READ-ONLY: everything is staged under $SCRATCH.
#
# Usage: scripts/falsify-wasm-e2e.sh [--strict] [--artifact PATH] [--keep]
#   --strict         regenerated crate differing from canonical is a failure (exit 21)
#   --artifact PATH  skip regen/stage/build; run the real tests against PATH
#   --keep           do not delete the scratch dir on exit
#
# Env:
#   WASM4PM_DIR            canonical wasm4pm checkout          (default ~/wasm4pm)
#   PACK_DIR               ex4pm-wasm4pm-bindings-pack         (default ~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack)
#   SCRATCH                scratch root                         (default mktemp)
#   REGEN_CMD              regen hook, run in the scratch consumer dir (default: ggen sync run --format json)
#   FALSIFY_MIX_BUILD_ROOT MIX_BUILD_ROOT for the mix test step (default: mix default)
#   MIN_REAL_WASM_TESTS    minimum real_wasm tests that must execute (default 5)
#
# Exit codes:
#   0  all good (>= MIN real_wasm tests ran, 0 failures, 0 skipped)
#   10 missing toolchain       20 regen failed        21 regenerated crate drifts (--strict)
#   30 cargo build failed      31 .wasm missing/empty
#   40 mix test failed         41 skips detected (vacuous pass)
#   42 fewer than MIN real_wasm tests executed

set -uo pipefail

EX4PM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WASM4PM_DIR="${WASM4PM_DIR:-$HOME/wasm4pm}"
PACK_DIR="${PACK_DIR:-$HOME/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack}"
MIN_REAL_WASM_TESTS="${MIN_REAL_WASM_TESTS:-5}"
CRATE=crates/wasm4pm-ex4pm-bindings
WASM_NAME=wasm4pm_ex4pm_bindings.wasm

STRICT=0
KEEP=0
ARTIFACT_OVERRIDE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1 ;;
    --keep) KEEP=1 ;;
    --artifact) shift; ARTIFACT_OVERRIDE="${1:-}" ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 10 ;;
  esac
  shift
done

if [ -z "${SCRATCH:-}" ]; then
  SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/falsify-wasm-e2e.XXXXXX")"
fi
mkdir -p "$SCRATCH"
if [ "$KEEP" -eq 0 ]; then
  trap 'rm -rf "$SCRATCH"' EXIT
fi

log() { printf '[falsify-wasm] %s\n' "$*"; }
die() { local code="$1"; shift; log "FAIL($code): $*"; exit "$code"; }
now() { date +%s; }

# ---- 1. preflight -------------------------------------------------------
log "preflight (ex4pm=$EX4PM_DIR wasm4pm=$WASM4PM_DIR scratch=$SCRATCH)"
need() { command -v "$1" >/dev/null 2>&1 || die 10 "missing tool: $1"; }
need mix
if [ -z "$ARTIFACT_OVERRIDE" ]; then
  need cargo
  need rsync
  need rustup
  [ -n "${REGEN_CMD:-}" ] || need ggen
  rustup target list --installed 2>/dev/null | grep -qx wasm32-unknown-unknown \
    || die 10 "rustup target wasm32-unknown-unknown not installed"
  [ -d "$WASM4PM_DIR/$CRATE" ] || die 10 "wasm4pm crate not found: $WASM4PM_DIR/$CRATE"
  [ -d "$PACK_DIR" ] || die 10 "pack dir not found: $PACK_DIR"
fi
[ -d "$EX4PM_DIR/deps/wasmex" ] || die 10 "deps/wasmex missing in $EX4PM_DIR (run mix deps.get once)"

ARTIFACT=""
if [ -n "$ARTIFACT_OVERRIDE" ]; then
  ARTIFACT="$ARTIFACT_OVERRIDE"
  log "--artifact given: skipping regen/stage/build"
else
  # ---- 2. stage wasm4pm copy (read-only on canonical) ---------------------
  STAGE="$SCRATCH/wasm4pm"
  t0=$(now)
  rsync -a --exclude target --exclude .git --exclude node_modules --exclude '*.wasm' \
    "$WASM4PM_DIR/" "$STAGE/" || die 30 "rsync stage failed"
  log "staged wasm4pm copy in $(( $(now) - t0 ))s"

  # ---- 3. regen via ggen pack (staged consumer) ---------------------------
  CONSUMER="$SCRATCH/consumer"
  mkdir -p "$CONSUMER/templates"
  cat > "$CONSUMER/ggen.toml" <<'EOF'
[project]
name = "ex4pm-wasm4pm-bindings-consumer"

[ontology]
source = "ontology.ttl"

[packs]
"ex4pm-wasm4pm-bindings-pack" = { path = "ex4pm-wasm4pm-bindings-pack" }

[templates]
dir = "templates"
EOF
  ln -sfn "$PACK_DIR" "$CONSUMER/ex4pm-wasm4pm-bindings-pack"
  ln -sfn ex4pm-wasm4pm-bindings-pack/ontology.ttl "$CONSUMER/ontology.ttl"

  REGEN_CMD="${REGEN_CMD:-ggen sync run --format json}"
  t0=$(now)
  ( cd "$CONSUMER" && eval "$REGEN_CMD" ) > "$SCRATCH/regen.log" 2>&1
  rc=$?
  [ $rc -eq 0 ] || { tail -20 "$SCRATCH/regen.log" >&2; die 20 "regen failed (exit $rc): $REGEN_CMD"; }
  [ -f "$CONSUMER/$CRATE/Cargo.toml" ] && [ -d "$CONSUMER/$CRATE/src" ] \
    || die 20 "regen produced no $CRATE"
  log "regen ok in $(( $(now) - t0 ))s"

  # drift: regenerated crate vs canonical crate (src + Cargo.toml)
  DRIFT=0
  diff -r "$CONSUMER/$CRATE/src" "$WASM4PM_DIR/$CRATE/src" > "$SCRATCH/drift.diff" 2>&1 || DRIFT=1
  diff "$CONSUMER/$CRATE/Cargo.toml" "$WASM4PM_DIR/$CRATE/Cargo.toml" >> "$SCRATCH/drift.diff" 2>&1 || DRIFT=1
  if [ "$DRIFT" -eq 1 ]; then
    log "WARNING: regenerated crate drifts from canonical ($(wc -l < "$SCRATCH/drift.diff") diff lines; head below)"
    head -20 "$SCRATCH/drift.diff"
    [ "$STRICT" -eq 1 ] && die 21 "regenerated crate drifts from canonical (--strict)"
  else
    log "regenerated crate == canonical (src + Cargo.toml)"
  fi

  # overlay regenerated crate onto the staged copy (so the build proves the REGENERATED source)
  rsync -a --delete "$CONSUMER/$CRATE/src/" "$STAGE/$CRATE/src/"
  cp "$CONSUMER/$CRATE/Cargo.toml" "$STAGE/$CRATE/Cargo.toml"

  # ---- 4. build wasm32 -----------------------------------------------------
  export CARGO_TARGET_DIR="$SCRATCH/target"
  t0=$(now)
  if [ -f "$STAGE/$CRATE/scripts/build-wasm.sh" ]; then
    log "build: $CRATE/scripts/build-wasm.sh (committed script)"
    ( cd "$STAGE" && bash "$CRATE/scripts/build-wasm.sh" ) > "$SCRATCH/build.log" 2>&1
    rc=$?
  else
    log "build: FALLBACK cargo build (no $CRATE/scripts/build-wasm.sh in canonical)"
    ( cd "$STAGE" && cargo build --locked -p wasm4pm-ex4pm-bindings \
        --target wasm32-unknown-unknown --release ) > "$SCRATCH/build.log" 2>&1
    rc=$?
  fi
  [ $rc -eq 0 ] || { tail -30 "$SCRATCH/build.log" >&2; die 30 "build failed (exit $rc)"; }
  log "build ok in $(( $(now) - t0 ))s"

  for c in "$CARGO_TARGET_DIR/wasm32-unknown-unknown/release/$WASM_NAME" \
           "$STAGE/target/wasm32-unknown-unknown/release/$WASM_NAME" \
           "$STAGE/$CRATE/$WASM_NAME"; do
    [ -s "$c" ] && { ARTIFACT="$c"; break; }
  done
  [ -n "$ARTIFACT" ] || ARTIFACT="$CARGO_TARGET_DIR/wasm32-unknown-unknown/release/$WASM_NAME"
fi

# ---- 5. artifact check -------------------------------------------------------
[ -s "$ARTIFACT" ] || die 31 ".wasm missing or empty: $ARTIFACT"
WASM_SHA="$(shasum -a 256 "$ARTIFACT" | awk '{print $1}')"
log "artifact: $ARTIFACT ($(wc -c < "$ARTIFACT") bytes) sha256=$WASM_SHA"

# ---- 6. real tests --------------------------------------------------------------
export EX4PM_WASM_ARTIFACT="$ARTIFACT"
export EX4PM_WASM_REQUIRED=1
export EX4PM_WASM_SHA256="$WASM_SHA"   # admission digest pin = the artifact this run built/was given
export MIX_ENV=test
[ -n "${FALSIFY_MIX_BUILD_ROOT:-}" ] && export MIX_BUILD_ROOT="$FALSIFY_MIX_BUILD_ROOT"

t0=$(now)
( cd "$EX4PM_DIR" && mix test test/wasm/real_transport_test.exs --include real_wasm ) \
  2>&1 | tee "$SCRATCH/mix-test.log"
mix_rc=${PIPESTATUS[0]}
log "mix test exit $mix_rc in $(( $(now) - t0 ))s"

SUMMARY="$(grep -E '^([0-9]+ doctests?, )?([0-9]+ properties, )?[0-9]+ tests?, [0-9]+ failures?' "$SCRATCH/mix-test.log" | tail -1)"
pick() { printf '%s' "$SUMMARY" | grep -oE "[0-9]+ $1" | head -1 | grep -oE '^[0-9]+'; }
TESTS="$(pick 'tests?')"
FAILS="$(pick 'failures?')"
SKIPS="$(pick 'skipped')"
EXCL="$(pick 'excluded')"
TESTS=${TESTS:-0}; FAILS=${FAILS:-0}; SKIPS=${SKIPS:-0}; EXCL=${EXCL:-0}
EXECUTED=$(( TESTS - SKIPS - EXCL ))
log "parsed: tests=$TESTS failures=$FAILS skipped=$SKIPS excluded=$EXCL executed=$EXECUTED  [$SUMMARY]"

[ "$mix_rc" -eq 0 ] && [ "$FAILS" -eq 0 ] || die 40 "mix test failed (exit $mix_rc, failures=$FAILS)"
[ -n "$SUMMARY" ] || die 40 "could not parse ExUnit summary (treating as failure)"
[ "$SKIPS" -eq 0 ] || die 41 "$SKIPS skipped test(s): vacuous pass"
[ "$EXECUTED" -ge "$MIN_REAL_WASM_TESTS" ] \
  || die 42 "only $EXECUTED real_wasm test(s) executed (< $MIN_REAL_WASM_TESTS)"

log "OK: $EXECUTED real_wasm tests executed, 0 failures, 0 skipped; wasm sha256=$WASM_SHA"
exit 0
