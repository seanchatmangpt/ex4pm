# Real WASM: wasm4pm-ex4pm-bindings

ex4pm executes the `wasm4pm-ex4pm-bindings` artifact in-process through Wasmex/Wasmtime.
Execution is gated by admission: the artifact must match a sha256 pin, compile, import nothing
outside the allowlist (empty in production) and export every required symbol. There is no
fixture path in the real transport; a result is `:alive` only when the exact admitted artifact
actually ran the request.

## Get the artifact

- **Bundled (new in 26.10.1):** `priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm`
  (2204812 bytes, zero imports, 70 function exports: 4 core plus 33 algorithms times
  request/replay, plus `memory`). `priv/wasm4pm/MANIFEST.json` pins it.
- **Build it yourself:** in a wasm4pm checkout run
  `crates/wasm4pm-ex4pm-bindings/scripts/build-wasm.sh`; the output is
  `target/wasm32-unknown-unknown/release/wasm4pm_ex4pm_bindings.wasm`.
- **Refresh the bundled copy and re-pin:** `scripts/refresh-wasm4pm-artifact.sh ~/wasm4pm`
  (see `priv/wasm4pm/README.md`).

## The sha256 pin

Pin precedence for admission: `start(path, expected_sha256: hex)`, then
`config :ex4pm, :wasm4pm_sha256, "hex"`, then `artifact.sha256` in `priv/wasm4pm/MANIFEST.json`.
With no pin admission fails closed (`:wasm_digest_unpinned`). A locally rebuilt artifact needs
either a re-pinned manifest or an explicit `expected_sha256`.

```bash
shasum -a 256 priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm
```

## Zero-config: `Ex4pmEngine.Wasm.Host` (new in 26.10.1)

The `:ex4pm` application supervises `Ex4pmEngine.Wasm.Host` (disable with
`config :ex4pm, :wasm_host, false`). It resolves the artifact path by precedence: start opt
`:artifact_path`, `config :ex4pm, :wasm4pm_artifact`, env `EX4PM_WASM_ARTIFACT`, then the
bundled file; admits it; and owns one Wasmex instance. A missing or unadmitted artifact does not
fail boot; the Host stays up and reports a typed refusal.

```elixir
Ex4pmEngine.Wasm.Host.status()
{:ok, transports} = Ex4pmEngine.Wasm.Host.transports()   # [discover_wasm_fun: fun, ...]

# With the Host running and admitted, adapters resolve their transport
# automatically (an explicit :<algo>_wasm_fun option still wins;
# wasm_default: false turns the fallback off).
Ex4pmEngine.Wasm.Discover.execute(:discover, %{traces: [["a", "b", "c"], ["a", "b"]]}, [])
```

## Explicit: `RealTransport.start/2`

```elixir
alias Ex4pmEngine.Wasm.{Discover, RealTransport}

# One instance, 33 transport closures:
{:ok, transports} = RealTransport.all_transports("/path/to/wasm4pm_ex4pm_bindings.wasm")
{:ok, result} = Discover.execute(:discover, %{traces: [["a", "b", "c"], ["a", "b"]]}, transports)

# Or drive a single export:
{:ok, instance} = RealTransport.start("/path/to/artifact.wasm", expected_sha256: "<hex>")
{:ok, response} = RealTransport.call(instance, "wasm4pm_ex4pm_discover_v1", %{traces: [["a", "b"]]})
{:ok, true} = RealTransport.replay(instance, "wasm4pm_ex4pm_discover_replay_v1", %{traces: [["a", "b"]]})
```

Runnable: `EX4PM_WASM_ARTIFACT=/path/to/artifact.wasm mix run examples/real_wasm_discover.exs`
(set `EX4PM_WASM_SHA256` when the artifact differs from the manifest pin).

Observed output against the pinned artifact:

```text
standing:    alive
replay:      true
value:       %{"activities" => ["a", "b", "c"], "edges" => [%{"freq" => 2, "from" => "a", "to" => "b"}, %{"freq" => 1, "from" => "b", "to" => "c"}]}
```

## Reading results

`Ex4pm.Engine.Result` fields to look at:

- `standing`: `:alive` iff the transport identity is observed (this run executed the admitted
  artifact, source SHA matches the adapter pin); `:partial_alive` when the response is valid
  but identity was not observed.
- `value`: the decoded algorithm result.
- `evidence`: `executed`, `replay_verified`, `request_digest`, `result_digest`,
  `wasm_export`, `wasm4pm_source_sha`, `transport_identity`, `authority: :construct_only`,
  `actuation_performed: false`.

## Typed refusals

Failures are `%Ex4pm.Refusal{}` values, not raises:

| Code | Meaning |
|---|---|
| `:wasm_digest_unpinned` | no pin supplied and none configured |
| `:wasm_digest_mismatch` | artifact bytes do not match the pin |
| `:wasm_invalid` | not a wasm binary, or failed to compile |
| `:wasm_import_surface_mismatch` | artifact imports outside the allowlist |
| `:wasm_missing_export` | a required export is absent |
| `:wasm_artifact_missing` | Host cannot read the artifact |
| `:invalid_encoding`, `:resource_limit`, `:abi_failure`, `:call_trapped`, `:call_timeout`, `:invalid_json`, `:malformed_response` | per-call transport failures |

The `ptr/len` UTF-8 JSON ABI is the bindings crate's own; ex4pm does not invent an OCEL string
ABI for arbitrary wasm-bindgen builds. See `docs/ARD-v26.9.x-wasm4pm-phase1.md`.
