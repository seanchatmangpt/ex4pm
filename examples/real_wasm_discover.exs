# Run: EX4PM_WASM_ARTIFACT=/path/to/wasm4pm_ex4pm_bindings.wasm mix run examples/real_wasm_discover.exs
#
# Admits the wasm4pm-ex4pm-bindings artifact (sha256 pin in
# priv/wasm4pm/MANIFEST.json, zero imports), starts a real Wasmex instance and
# runs the `discover` adapter against it. Missing/mismatched artifact => typed
# refusal printed, exit 1.
alias Ex4pmEngine.Wasm.{Discover, RealTransport}

artifact =
  System.get_env("EX4PM_WASM_ARTIFACT") ||
    Path.expand("~/wasm4pm/target/wasm32-unknown-unknown/release/wasm4pm_ex4pm_bindings.wasm")

# EX4PM_WASM_SHA256 overrides the manifest pin (e.g. for a locally rebuilt artifact).
start_opts =
  case System.get_env("EX4PM_WASM_SHA256") do
    hex when hex in [nil, ""] -> []
    hex -> [expected_sha256: hex]
  end

with {:ok, transports} <- RealTransport.all_transports(artifact, start_opts),
     {:ok, result} <-
       Discover.execute(:discover, %{traces: [["a", "b", "c"], ["a", "b"]]}, transports) do
  IO.puts("standing:    #{result.standing}")
  IO.puts("replay:      #{result.evidence.replay_verified}")
  IO.puts("value:       #{inspect(result.value)}")
else
  {:error, refusal} ->
    IO.puts("REFUSED: #{inspect(refusal)}")
    System.halt(1)
end
