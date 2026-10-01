#!/usr/bin/env bash
# Rebuild the ex4pm WASM bindings from a wasm4pm checkout, verify, and re-pin the bundle.
# Usage: scripts/refresh-wasm4pm-artifact.sh <path-to-wasm4pm-checkout>
# Touches only priv/wasm4pm/{wasm4pm_ex4pm_bindings.wasm,MANIFEST.json}. Idempotent.
set -euo pipefail

SRC="${1:?usage: $0 <wasm4pm-checkout>}"
SRC="$(cd "$SRC" && pwd)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$(cd "$HERE/.." && pwd)/priv/wasm4pm"
ABI="$SRC/docs/abi/ex4pm-bindings.abi.json"
SCRATCH="$(mktemp -d "${TMPDIR:-/private/tmp}/w4pm-refresh.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT

[ -f "$SRC/crates/wasm4pm-ex4pm-bindings/scripts/build-wasm.sh" ] || { echo "not a wasm4pm checkout: $SRC" >&2; exit 1; }
[ -f "$ABI" ] || { echo "missing ABI doc $ABI" >&2; exit 1; }

(cd "$SRC" && CARGO_TARGET_DIR="$SCRATCH/target" RUSTUP_TOOLCHAIN="${RUSTUP_TOOLCHAIN:-nightly-2026-04-15}" \
  bash crates/wasm4pm-ex4pm-bindings/scripts/build-wasm.sh)

OUT="$SCRATCH/target/wasm32-unknown-unknown/release/wasm4pm_ex4pm_bindings.wasm"
[ -f "$OUT" ] || { echo "build produced no artifact" >&2; exit 1; }

COMMIT="$(git -C "$SRC" rev-parse HEAD)"
BRANCH="$(git -C "$SRC" branch --show-current)"

python3 - "$OUT" "$ABI" <<'PY'
import json, sys
b = open(sys.argv[1], 'rb').read()
abi = json.load(open(sys.argv[2]))
assert b[:4] == b'\0asm', 'not wasm'
def leb(i):
    r = s = 0
    while True:
        x = b[i]; i += 1; r |= (x & 127) << s; s += 7
        if not x & 128: return r, i
i = 8; imports = 0; exports = []
while i < len(b):
    sid = b[i]; i += 1; sz, i = leb(i); end = i + sz
    if sid == 2: imports, _ = leb(i)
    if sid == 7:
        n, j = leb(i)
        for _ in range(n):
            l, j = leb(j); nm = b[j:j+l].decode(); j += l; k = b[j]; j += 1; _, j = leb(j)
            if k == 0: exports.append(nm)
    i = end
want = sorted(e['export'] for e in abi['exports'])
assert imports == 0, f'imports={imports}, expected 0'
assert sorted(exports) == want, f'export mismatch: missing={set(want)-set(exports)} extra={set(exports)-set(want)}'
assert len(want) == abi['export_count'] == 70, 'export count != 70'
print(f'verified: imports=0 function_exports={len(want)}')
PY

cp "$OUT" "$DEST/wasm4pm_ex4pm_bindings.wasm"
SHA="$(shasum -a 256 "$DEST/wasm4pm_ex4pm_bindings.wasm" | cut -d' ' -f1)"
SIZE="$(wc -c <"$DEST/wasm4pm_ex4pm_bindings.wasm" | tr -d ' ')"

python3 - "$DEST/MANIFEST.json" "$SHA" "$SIZE" "$COMMIT" "$BRANCH" <<'PY'
import json, sys
p, sha, size, commit, branch = sys.argv[1:]
m = json.load(open(p))
m['artifact'].update(path='wasm4pm_ex4pm_bindings.wasm', sha256=sha, size=int(size))
m['provenance'].update(source_commit=commit, source_branch=branch, export_count=70, import_count=0)
open(p, 'w').write(json.dumps(m, indent=2) + '\n')
PY
echo "pinned sha256=$SHA size=$SIZE commit=$COMMIT"
