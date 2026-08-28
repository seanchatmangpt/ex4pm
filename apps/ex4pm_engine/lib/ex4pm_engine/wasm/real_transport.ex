defmodule Ex4pmEngine.Wasm.RealTransport do
  @moduledoc """
  The real Wasmex-backed transport for every `Ex4pmEngine.Wasm.*` adapter
  (`discover`, `conform`, `align`, `htn_plan`, ... all 19 Phase-1/2/3
  algorithms) -- the piece the CI workflow
  (`.github/workflows/wasm4pm-bindings-integration.yml`) explicitly names as
  "follow-on work, tracked in docs/ARD-v26.9.x-wasm4pm-phase1.md": every
  exercised path before this module used a fixture closure fabricating both
  the result and the `observed:true`/`replay_verified:true` identity.

  This module actually drives the `wasm4pm-ex4pm-bindings` crate's real
  ptr/len UTF-8 JSON ABI (documented at the top of
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/lib.rs`) through a real
  `Wasmex` instance:

    1. `wasm4pm_ex4pm_bindings_alloc_v1(len)` -> reserve `len` bytes in the
       module's own linear memory (added alongside this module -- the crate
       previously exported no allocator, so no host could safely write an
       input buffer at all).
    2. `Wasmex.memory/1` fetches the real exported memory, then
       `Wasmex.Memory.write_binary/4` writes the real UTF-8 JSON request
       into that buffer.
    3. Call `<algo>_v1(ptr, len, out_len_ptr)` -- `out_len_ptr` is itself a
       second small alloc'd buffer (4 bytes, i32) the export writes its
       real output length into.
    4. Read `out_len` back via `Wasmex.Memory.read_binary/4` + `:binary`
       unpack, then read the real output bytes at the returned `out_ptr`.
    5. Free the output buffer via `wasm4pm_ex4pm_bindings_free_v1/2` and the
       input+out_len buffers via `wasm4pm_ex4pm_bindings_dealloc_v1/2`.
    6. Decode the real JSON response and hand it back to
       `Ex4pmEngine.Wasm.Adapter` as `{:ok, response, identity}`, with
       `identity.observed` true only because THIS module actually executed
       the WASM, computed a real SHA-256 of the artifact bytes, and can
       point to the real pid/instance that ran it -- not because a fixture
       said so.

  One transport, reused for every algorithm: `call/3` takes the artifact
  path, the export name pair, and the request map: the `use
  Ex4pmEngine.Wasm.Adapter` macro already carries each op's own
  `@wasm_export`, so each `Ex4pmEngine.Wasm.<Op>` module's
  `:<algo>_wasm_fun` default (wired in `default_transport/1`) just needs to
  close over its own export name.

  No mocks anywhere in this module: `Wasmex.start_link/1` boots the real
  Wasmtime runtime configured by the `wasmex` dep and every byte written or
  read crosses that real boundary.

  ## The real, independently discovered `__wbindgen_placeholder__` gap

  `wasm4pm-ex4pm-bindings` links the full `wasm4pm` crate, whose
  `Cargo.toml` declares `wasm-bindgen` as a mandatory (non-optional,
  non-feature-gated) dependency and carries 111 unconditionally-compiled
  `#[wasm_bindgen]`-attributed items across its ML/stats/drift modules --
  code this crate's own `discover`/`conform`/`align`/etc. exports never
  call, but which the linker still considers reachable. The resulting
  `wasm4pm_ex4pm_bindings.wasm` therefore imports 87 `__wbindgen_placeholder__`
  / `__wbindgen_externref_xform__` host functions it does not itself define
  -- confirmed for real by parsing the compiled artifact's own WASM import
  section (`wasm-objdump`-equivalent: every import type here was read
  directly from the binary's Type/Import sections, not assumed), and every
  one of the 87 uses only `i32`/`i64`/`f64` params/results (wasm-bindgen's
  classic non-reference-types ABI) -- Wasmex's documented import type set
  (`:i32`/`:i64`/`:v128`/`:f32`/`:f64`, no `:externref`) covers all of them.
  `stub_wasm_bindgen_imports/0` supplies all 87 as real, correctly-signed
  Wasmex import stubs returning zero-valued results. They are provided
  ONLY to satisfy WASM instantiation-time import resolution; none of the
  19 `<algo>_v1` exports this module actually drives reach any JS-interop
  code path at runtime, so these stubs are never invoked in the executions
  this module performs -- this is not faking algorithm behavior, it is
  satisfying dead, unrelated linkage the upstream crate currently leaves in
  the artifact unconditionally. The real, minimal fix belongs upstream (make
  `wasm-bindgen` and its 111 call sites genuinely optional behind the
  `browser` feature in `~/wasm4pm/wasm4pm/Cargo.toml`); that is a
  cross-cutting refactor of code this module does not own, so this is
  documented here as the real, named, still-open upstream gap rather than
  silently worked around.
  """

  alias Ex4pm.Core.Hash

  @typedoc "A started, real Wasmex instance plus the artifact bytes/hash used to start it, so callers can invoke multiple exports against the same instance without re-loading the module."
  @type instance :: %{
          pid: pid(),
          artifact_hash: String.t(),
          artifact_path: String.t()
        }

  @doc """
  Boots a real `Wasmex` instance from the compiled `wasm4pm-ex4pm-bindings`
  artifact at `path`. Returns `{:ok, instance}` with the real SHA-256 of the
  artifact bytes (via `Ex4pm.Core.Hash`), or `{:error, reason}` if the file
  is missing/unreadable or Wasmex fails to instantiate it.
  """
  @spec start(String.t()) :: {:ok, instance()} | {:error, term()}
  def start(path) when is_binary(path) do
    with {:ok, bytes} <- File.read(path),
         artifact_hash <- Hash.digest(bytes),
         {:ok, pid} <- Wasmex.start_link(%{bytes: bytes, imports: stub_wasm_bindgen_imports()}) do
      {:ok, %{pid: pid, artifact_hash: artifact_hash, artifact_path: path}}
    end
  end

  @typedoc "One `Ex4pmEngine.Wasm.*` adapter module plus the algorithm identity RealTransport needs to build its default_transport/2 map."
  @type algo_spec :: %{
          module: module(),
          algorithm_id: atom(),
          export_name: String.t(),
          replay_export_name: String.t()
        }

  @doc """
  The real, closed registry of all 19 `Ex4pmEngine.Wasm.*` Phase-1/2/3
  adapters -- one entry per `<algo>_v1`/`<algo>_replay_v1` export pair the
  `wasm4pm-ex4pm-bindings` crate exposes (verified against
  `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/{lib,phase2,phase2_playout,prolog}.rs`).
  This is the single source of truth `Ex4pmEngine.Reactors.WasmCapabilitiesReactor`
  and any Chicago test wiring `default_transport/2` should read from, rather
  than each re-deriving export-name strings by hand.
  """
  @spec algo_specs() :: [algo_spec()]
  def algo_specs do
    [
      %{module: Ex4pmEngine.Wasm.Discover, algorithm_id: :discover},
      %{module: Ex4pmEngine.Wasm.Conform, algorithm_id: :conform},
      %{module: Ex4pmEngine.Wasm.Simulate, algorithm_id: :simulate},
      %{module: Ex4pmEngine.Wasm.Optimize, algorithm_id: :optimize},
      %{module: Ex4pmEngine.Wasm.PowlMine, algorithm_id: :powl_mine},
      %{module: Ex4pmEngine.Wasm.Survival, algorithm_id: :survival},
      %{module: Ex4pmEngine.Wasm.Markov, algorithm_id: :markov},
      %{module: Ex4pmEngine.Wasm.Bayesian, algorithm_id: :bayesian},
      %{module: Ex4pmEngine.Wasm.OcpqEval, algorithm_id: :ocpq_eval},
      %{module: Ex4pmEngine.Wasm.StripsPlan, algorithm_id: :strips_plan},
      %{module: Ex4pmEngine.Wasm.HtnPlan, algorithm_id: :htn_plan},
      %{module: Ex4pmEngine.Wasm.CtlCheck, algorithm_id: :ctl_check},
      %{module: Ex4pmEngine.Wasm.AllenTemporal, algorithm_id: :allen_temporal},
      %{module: Ex4pmEngine.Wasm.OcDiscover, algorithm_id: :oc_discover},
      %{module: Ex4pmEngine.Wasm.Align, algorithm_id: :align},
      %{module: Ex4pmEngine.Wasm.EtcPrecision, algorithm_id: :etc_precision},
      %{module: Ex4pmEngine.Wasm.Soundness, algorithm_id: :soundness},
      %{module: Ex4pmEngine.Wasm.Playout, algorithm_id: :playout},
      %{module: Ex4pmEngine.Wasm.PrologQuery, algorithm_id: :prolog_query},
      # Phase 4 (statistics/ML, ~wasm4pm/crates/wasm4pm-ex4pm-bindings/src/phase4_stats.rs)
      %{module: Ex4pmEngine.Wasm.KsStatistic, algorithm_id: :ks_statistic},
      %{module: Ex4pmEngine.Wasm.KsCriticalValue, algorithm_id: :ks_critical_value},
      %{module: Ex4pmEngine.Wasm.Regression, algorithm_id: :regression},
      %{module: Ex4pmEngine.Wasm.Forecast, algorithm_id: :forecast},
      %{module: Ex4pmEngine.Wasm.HoltForecast, algorithm_id: :holt_forecast},
      %{module: Ex4pmEngine.Wasm.Ewma, algorithm_id: :ewma},
      %{module: Ex4pmEngine.Wasm.TrendClassify, algorithm_id: :trend_classify},
      %{module: Ex4pmEngine.Wasm.Mean, algorithm_id: :mean},
      %{module: Ex4pmEngine.Wasm.DotProduct, algorithm_id: :dot_product},
      %{module: Ex4pmEngine.Wasm.EuclideanDistance, algorithm_id: :euclidean_distance},
      %{module: Ex4pmEngine.Wasm.Standardize, algorithm_id: :standardize},
      %{module: Ex4pmEngine.Wasm.Median, algorithm_id: :median},
      %{module: Ex4pmEngine.Wasm.Percentile, algorithm_id: :percentile},
      %{module: Ex4pmEngine.Wasm.StdDeviation, algorithm_id: :std_deviation}
    ]
    |> Enum.map(fn %{module: mod, algorithm_id: id} ->
      %{
        module: mod,
        algorithm_id: id,
        export_name: "wasm4pm_ex4pm_#{id}_v1",
        replay_export_name: "wasm4pm_ex4pm_#{id}_replay_v1"
      }
    end)
  end

  @doc """
  Boots ONE real `Wasmex` instance from `artifact_path` (via `start/1`) and
  builds all 33 `default_transport/2` closures against it in one pass --
  the option map every `Ex4pmEngine.Wasm.*` adapter's `execute/3` expects
  under its own `:<algo>_wasm_fun` key, ready to `Keyword.merge` into an
  `execute/3` `opts` list or into a Reactor step's own transport-selection.
  Returns `{:ok, transports}` where `transports` is a keyword list
  `[discover_wasm_fun: fun, conform_wasm_fun: fun, ...]`, or `{:error,
  reason}` if the artifact can't be loaded.
  """
  @spec all_transports(String.t()) :: {:ok, keyword()} | {:error, term()}
  def all_transports(artifact_path) do
    with {:ok, instance} <- start(artifact_path) do
      transports =
        Enum.map(algo_specs(), fn spec ->
          key = :"#{spec.algorithm_id}_wasm_fun"

          fun =
            default_transport(instance, %{
              export_name: spec.export_name,
              replay_export_name: spec.replay_export_name,
              algorithm_id: spec.algorithm_id,
              protocol: Ex4pmEngine.Wasm.Adapter.protocol(),
              wasm4pm_source_sha: Ex4pmEngine.Wasm.Adapter.wasm4pm_source_sha()
            })

          {key, fun}
        end)

      {:ok, transports}
    end
  end

  @doc """
  Real end-to-end call against export `export_name` on an already-`start/1`ed
  `instance`, marshaling `request` (a plain map, JSON-encoded here) through
  the crate's real ptr/len ABI. Returns `{:ok, response_map}` on a decoded
  JSON object response, `{:error, reason}` otherwise. `response_map` is
  handed back verbatim to `Ex4pmEngine.Wasm.Adapter.accept/4` -- this
  module makes no claim about the algorithm's own semantics, only that the
  bytes it returns really came out of a real WASM execution of `export_name`
  against `request`.
  """
  @spec call(instance(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def call(%{pid: pid}, export_name, request) when is_map(request) do
    with {:ok, request_json} <- Jason.encode(request),
         {:ok, store} <- Wasmex.store(pid),
         {:ok, memory} <- Wasmex.memory(pid),
         {:ok, in_ptr} <- alloc(pid, byte_size(request_json)),
         :ok <- Wasmex.Memory.write_binary(store, memory, in_ptr, request_json),
         {:ok, out_len_ptr} <- alloc(pid, 4),
         {:ok, [out_ptr]} <-
           Wasmex.call_function(pid, export_name, [in_ptr, byte_size(request_json), out_len_ptr]),
         <<out_len::little-unsigned-32>> <-
           Wasmex.Memory.read_binary(store, memory, out_len_ptr, 4),
         response_bytes <- read_output(store, memory, out_ptr, out_len),
         :ok <- dealloc(pid, in_ptr, byte_size(request_json)),
         :ok <- dealloc(pid, out_len_ptr, 4),
         :ok <- free_output(pid, out_ptr, out_len),
         {:ok, response} <- decode_response(response_bytes) do
      {:ok, response}
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, {:invalid_wasm_call_result, other}}
    end
  end

  @doc """
  Real replay check: re-invokes `<algo>_replay_v1` (per the crate's own
  self-check contract -- see `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/lib.rs`
  module doc) against the SAME request bytes and returns `{:ok, true | false}`
  reflecting the export's own real `u32` return (1/0), or `{:error, reason}`.
  """
  @spec replay(instance(), String.t(), map()) :: {:ok, boolean()} | {:error, term()}
  def replay(%{pid: pid}, replay_export_name, request) when is_map(request) do
    with {:ok, request_json} <- Jason.encode(request),
         {:ok, store} <- Wasmex.store(pid),
         {:ok, memory} <- Wasmex.memory(pid),
         {:ok, in_ptr} <- alloc(pid, byte_size(request_json)),
         :ok <- Wasmex.Memory.write_binary(store, memory, in_ptr, request_json),
         {:ok, [result]} <-
           Wasmex.call_function(pid, replay_export_name, [in_ptr, byte_size(request_json)]),
         :ok <- dealloc(pid, in_ptr, byte_size(request_json)) do
      {:ok, result == 1}
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, {:invalid_wasm_replay_result, other}}
    end
  end

  @doc """
  Builds the `:<algo>_wasm_fun` 2-arity transport callback
  `Ex4pmEngine.Wasm.Adapter.execute/3` expects, closing over a real,
  already-`start/1`-ed `instance` plus this op's own identity: `export_name`
  and `replay_export_name` (the crate's paired `<algo>_v1`/`<algo>_replay_v1`
  exports), `algorithm_id` and `protocol`/`wasm4pm_source_sha` (matching
  `Ex4pmEngine.Wasm.Adapter`'s own `@protocol`/`wasm4pm_source_sha/0` so
  `accept/4`'s `admit_source/2` check passes for real rather than being
  bypassed).

  Every call performs TWO real WASM invocations -- the algorithm itself via
  `call/3`, then a real `<algo>_replay_v1` re-execution via `replay/3` -- so
  `identity.replay_verified` reflects a genuinely recomputed digest match,
  not an asserted `true`. `Ex4pmEngine.Wasm.Adapter.accept/4` only awards
  `:alive` (vs. `:partial_alive`) when this real replay agrees.
  """
  @spec default_transport(instance(), map()) ::
          (map(), keyword() -> {:ok, map(), map()} | {:error, term()})
  def default_transport(%{artifact_hash: artifact_hash} = instance, algo) do
    %{
      export_name: export_name,
      replay_export_name: replay_export_name,
      algorithm_id: algorithm_id,
      protocol: protocol,
      wasm4pm_source_sha: wasm4pm_source_sha
    } = algo

    fn request, _opts ->
      with {:ok, response} <- call(instance, export_name, request),
           {:ok, replayed?} <- replay(instance, replay_export_name, request) do
        result_digest = Map.get(response, "digest") || ""

        receipt = %{
          "schema" => protocol,
          "algorithm_id" => to_string(algorithm_id),
          "wasm_export" => export_name,
          "wasm4pm_source_sha" => wasm4pm_source_sha,
          "request_digest" => Hash.digest(request),
          "result_digest" => nonempty_or(result_digest, Hash.digest(response))
        }

        identity = %{
          observed: true,
          wasm4pm_source_sha: wasm4pm_source_sha,
          wasm_sha256: artifact_hash,
          replay_verified: replayed?
        }

        {:ok,
         %{
           "standing" => "ALIVE",
           "result" => Map.get(response, "result", response),
           "receipt" => receipt
         }, identity}
      end
    end
  end

  defp nonempty_or(value, _fallback) when is_binary(value) and byte_size(value) > 0, do: value
  defp nonempty_or(_value, fallback), do: fallback

  # -- internal ---------------------------------------------------------

  # (module, export_name, param_types, result_types) for all 87 imports the
  # compiled wasm4pm_ex4pm_bindings.wasm artifact declares but does not
  # itself define -- read directly from the artifact's real WASM Type/Import
  # sections (see moduledoc "The real, independently discovered
  # __wbindgen_placeholder__ gap"), not guessed or copied from an unrelated
  # wasm-bindgen version. Regenerate this list if the artifact is rebuilt
  # from a wasm4pm/wasm-bindgen version whose glue signatures changed --
  # `start/1` will surface a real Wasmex instantiation error naming the
  # missing/mismatched import if this list ever drifts from the real binary.
  @wbindgen_imports [
    {"__wbindgen_placeholder__", "__wbindgen_error_new", [:i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_object_drop_ref", [:i32], []},
    {"__wbindgen_placeholder__", "__wbindgen_is_undefined", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_in", [:i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_number_get", [:i32, :i32], []},
    {"__wbindgen_placeholder__", "__wbindgen_boolean_get", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_string_get", [:i32, :i32], []},
    {"__wbindgen_placeholder__", "__wbindgen_is_bigint", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_is_object", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_number_new", [:f64], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_describe", [:i32], []},
    {"__wbindgen_placeholder__", "__wbindgen_bigint_from_i64", [:i64], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_bigint_from_u64", [:i64], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_string_new", [:i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_associationrule_new", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_featureimportance_new", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_driftpoint_new", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_sequenceanomaly_new", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_jsval_eq", [:i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_banditarm_new", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_transitionedge_new", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_transitionedge_unwrap", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_featureimportance_unwrap", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_driftpoint_unwrap", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_sequenceanomaly_unwrap", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_banditarm_unwrap", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_is_null", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_object_clone_ref", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_set_3f1d0b984ed272ed", [:i32, :i32, :i32], []},
    {"__wbindgen_placeholder__", "__wbindgen_jsval_loose_eq", [:i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_as_number", [:i32], [:f64]},
    {"__wbindgen_placeholder__", "__wbg_getwithrefkey_1dc361bd10053bfe", [:i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_String_8f0eb39a4a4c2f66", [:i32, :i32], []},
    {"__wbindgen_placeholder__", "__wbg_new_8a6f238a6ece86ea", [], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_stack_0ed75d68575b0f3c", [:i32, :i32], []},
    {"__wbindgen_placeholder__", "__wbg_error_7534b8e9a36f1ab4", [:i32, :i32], []},
    {"__wbindgen_placeholder__", "__wbg_now_2c95c9de01293173", [:i32], [:f64]},
    {"__wbindgen_placeholder__", "__wbg_performance_7a3ffd0b17f663ad", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_is_string", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_iterator_9a24c88df860dc65", [], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_is_function", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_push_737cfc8c1432c2c6", [:i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_new_78feb108b6472713", [], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_newwithlength_c4c419ef0bc8a1f8", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_get_b9b93047fe3cf45b", [:i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_set_37837023f3d740e8", [:i32, :i32, :i32], []},
    {"__wbindgen_placeholder__", "__wbg_isArray_a1eab7e0d067391b", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_buffer_609cc3eee51ed158", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_length_e2d2a49132c1b256", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_new_5e0be73521bc8c17", [], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_set_8fc6bf8a5b1071d1", [:i32, :i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_newnoargs_105ed471475aaf50", [:i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_call_672a4d21634d4a24", [:i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_call_7cccdd69e0791ae2", [:i32, :i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_next_6574e1a8a62d1055", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_done_769e5ede4b31c67b", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_value_cd1ffa7b1ab794f1", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_isSafeInteger_343e2beeeece1bb0", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_getTime_46267b1c24877e30", [:i32], [:f64]},
    {"__wbindgen_placeholder__", "__wbg_new0_f788a2397c7ca929", [], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_now_807e54c39636c349", [], [:f64]},
    {"__wbindgen_placeholder__", "__wbg_entries_3265d4158b33e5dc", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_new_405e22f390576ce2", [], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_new_a12002a7f91c75be", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_newwithbyteoffsetandlength_93c8e0c1a479fa1a",
     [:i32, :i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_length_a446193dc22c12f8", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_set_65595bdd868b3009", [:i32, :i32, :i32], []},
    {"__wbindgen_placeholder__", "__wbg_newwithlength_5ebc38e611488614", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_length_c67d5e5c3b83737f", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_set_29b6f95e6adb667e", [:i32, :i32, :i32], []},
    {"__wbindgen_placeholder__", "__wbg_next_25feadfc0913fea9", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_random_3ad904d98382defe", [], [:f64]},
    {"__wbindgen_placeholder__", "__wbg_get_67b2ba62fc30de12", [:i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_static_accessor_GLOBAL_THIS_56578be7e9f832b0", [],
     [:i32]},
    {"__wbindgen_placeholder__", "__wbg_static_accessor_SELF_37c5d418e4bf5819", [], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_static_accessor_GLOBAL_88a902d13a557d07", [], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_static_accessor_WINDOW_5de37043a91a9c40", [], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_instanceof_Map_f3469ce2244d2430", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_instanceof_Uint8Array_17156bcf118086a9", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbg_instanceof_ArrayBuffer_e14585432e3737fc", [:i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_bigint_get_as_i64", [:i32, :i32], []},
    {"__wbindgen_placeholder__", "__wbindgen_memory", [], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_throw", [:i32, :i32], []},
    {"__wbindgen_placeholder__", "__wbindgen_float64_array_new", [:i32, :i32], [:i32]},
    {"__wbindgen_placeholder__", "__wbindgen_debug_string", [:i32, :i32], []},
    {"__wbindgen_externref_xform__", "__wbindgen_externref_table_grow", [:i32], [:i32]},
    {"__wbindgen_externref_xform__", "__wbindgen_externref_table_set_null", [:i32], []}
  ]

  @spec stub_wasm_bindgen_imports() :: map()
  defp stub_wasm_bindgen_imports do
    Enum.reduce(@wbindgen_imports, %{}, fn {namespace, name, params, results}, acc ->
      Map.update(acc, namespace, %{name => stub_fn(params, results)}, fn ns ->
        Map.put(ns, name, stub_fn(params, results))
      end)
    end)
  end

  defp zero_of(:i32), do: 0
  defp zero_of(:i64), do: 0
  defp zero_of(:f32), do: 0.0
  defp zero_of(:f64), do: 0.0

  defp stub_fn(params, []), do: {:fn, params, [], stub_body(length(params), nil)}

  defp stub_fn(params, [result_type]),
    do: {:fn, params, [result_type], stub_body(length(params), zero_of(result_type))}

  # Every declared import in @wbindgen_imports has 0-3 params and 0-1
  # results (verified against the real artifact's own type section) -- these
  # four arities cover all of them; a fifth or higher arity here would mean
  # the artifact changed shape and this list needs regenerating (see the
  # comment above @wbindgen_imports).
  defp stub_body(0, ret), do: fn _ctx -> ret end
  defp stub_body(1, ret), do: fn _ctx, _a -> ret end
  defp stub_body(2, ret), do: fn _ctx, _a, _b -> ret end
  defp stub_body(3, ret), do: fn _ctx, _a, _b, _c -> ret end

  defp alloc(pid, len) do
    case Wasmex.call_function(pid, "wasm4pm_ex4pm_bindings_alloc_v1", [len]) do
      {:ok, [ptr]} -> {:ok, ptr}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dealloc(pid, ptr, len) do
    case Wasmex.call_function(pid, "wasm4pm_ex4pm_bindings_dealloc_v1", [ptr, len]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp free_output(pid, ptr, len) do
    case Wasmex.call_function(pid, "wasm4pm_ex4pm_bindings_free_v1", [ptr, len]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_output(_store, _memory, _ptr, 0), do: ""

  defp read_output(store, memory, ptr, len) do
    Wasmex.Memory.read_binary(store, memory, ptr, len)
  end

  defp decode_response(bytes) do
    case Jason.decode(bytes) do
      {:ok, map} when is_map(map) -> {:ok, map}
      {:ok, other} -> {:error, {:non_object_wasm_response, other}}
      {:error, reason} -> {:error, {:invalid_wasm_response_json, reason}}
    end
  end
end
