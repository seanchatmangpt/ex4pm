# ggen/bindings

Sandboxed ggen consumer of `ex4pm-wasm4pm-bindings-pack` (symlinked from
`~/ggen-marketplace/packs/`). Nothing generated here is promoted into
`ex4pm/lib/`; this directory only proves the pack syncs against the ggen CLI.

    cd ggen/bindings
    ggen sync run --dry-run --format json
    ggen sync run --format json

Paths in `ggen.toml` are symlink-relative (ggen refuses `..`). Staging outputs
(`lib/`, `crates/`, `.clap-noun-verb/`) are gitignored.

`ggen.lock` pins the pack content hash (FM-PACK-008 on mismatch). After the pack
changes, delete `ggen.lock`, `lib/`, `crates/`, `.ggen-v2/` and re-run the sync.
Last run: pack 0.1.2, ontology.ttl sha256
`2fcd79660b8769c340364ff510f50fe75b47a52839ec43e6db674da4a648dd1e`
(git blob `3394d0ebd398a99d7c4c12a79d2d92a04710b096`), 39 files staged.
