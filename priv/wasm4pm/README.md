# priv/wasm4pm

Bundled, digest-pinned `wasm4pm_ex4pm_bindings.wasm` (zero imports, 70 function exports:
4 core + 33 algos x request/replay, plus `memory`). `MANIFEST.json` pins the sha256, size
and build provenance; `Ex4pmEngine.Wasm.Admission` reads `artifact.sha256` and
`host_abi.imports`.

Refresh (rebuild from a wasm4pm checkout, verify, re-pin):

```bash
scripts/refresh-wasm4pm-artifact.sh ~/wasm4pm
```

The script needs the `nightly-2026-04-15` toolchain and rewrites only the wasm file and the
manifest `sha256`/`size`/`source_commit`/`source_branch`. Commit both together.
