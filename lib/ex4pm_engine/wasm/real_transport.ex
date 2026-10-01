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

  ## Zero-import artifact

  The artifact is linked by `wasm4pm-ex4pm-bindings/scripts/build-wasm.sh`
  (staticlib + `rust-lld`, exporting only the allowlisted `export_name`
  symbols) and imports NOTHING. `priv/wasm4pm/MANIFEST.json`
  `host_abi.imports` is therefore empty, and `Ex4pmEngine.Wasm.Admission`
  refuses any artifact that imports a host function. `stub_imports/1` only
  materializes imports that an explicit `:import_allowlist` override admits
  (used by tests against a real fixture module); for the production
  allowlist it yields `%{}`.
  """

  alias Ex4pm.Core.Hash

  @typedoc "A started, real Wasmex instance plus the artifact bytes/hash used to start it, so callers can invoke multiple exports against the same instance without re-loading the module."
  @type instance :: %{
          pid: pid(),
          artifact_hash: String.t(),
          artifact_path: String.t()
        }

  alias Ex4pm.Refusal
  alias Ex4pmEngine.Wasm.Admission

  @max_request_bytes 16 * 1024 * 1024
  @max_response_bytes 64 * 1024 * 1024
  @call_timeout_ms 5_000

  @doc """
  Boots a real `Wasmex` instance from the compiled `wasm4pm-ex4pm-bindings`
  artifact at `path` under the default digest pin (see `start/2`).
  """
  @spec start(String.t()) :: {:ok, instance()} | {:error, term()}
  def start(path) when is_binary(path), do: start(path, [])

  @doc """
  Admits (`Ex4pmEngine.Wasm.Admission.admit/2`: digest pin, compile, import
  allowlist, required exports) and then boots the artifact at `path`.

  Options: `:expected_sha256` (hex | `:unpinned`; default is Application env
  `:ex4pm, :wasm4pm_sha256`, else `priv/wasm4pm/MANIFEST.json`
  `artifact.sha256`; a `nil` pin is refused `:wasm_digest_unpinned`),
  `:import_allowlist`, `:required_exports` (passed through to admission).

  Instantiation imports are stubs derived from the SAME allowlist admission
  judged, so allowlist and stubs cannot drift. Returns `{:ok, instance}` with
  the real SHA-256 of the artifact bytes (via `Ex4pm.Core.Hash`),
  `{:error, posix}` if the file cannot be read, or `{:error, %Ex4pm.Refusal{}}`.
  """
  @spec start(String.t(), keyword()) :: {:ok, instance()} | {:error, term()}
  def start(path, opts) when is_binary(path) and is_list(opts) do
    with {:ok, bytes} <- File.read(path),
         {:ok, admitted} <- Admission.admit(bytes, admission_opts(opts)),
         {:ok, store} <- Wasmex.Store.new(nil, admitted.engine),
         {:ok, pid} <-
           Wasmex.start_link(%{
             store: store,
             module: admitted.module,
             imports: stub_imports(admitted.allowlist)
           }) do
      {:ok, %{pid: pid, artifact_hash: Hash.digest(bytes), artifact_path: path}}
    end
  end

  defp admission_opts(opts) do
    pin =
      case Keyword.fetch(opts, :expected_sha256) do
        {:ok, pin} ->
          pin

        :error ->
          Application.get_env(:ex4pm, :wasm4pm_sha256) || Admission.manifest_sha256()
      end

    opts
    |> Keyword.take([:import_allowlist, :required_exports])
    |> Keyword.put(:expected_sha256, pin)
  end

  @typedoc "One `Ex4pmEngine.Wasm.*` adapter module plus the algorithm identity RealTransport needs to build its default_transport/2 map."
  @type algo_spec :: %{
          module: module(),
          algorithm_id: atom(),
          export_name: String.t(),
          replay_export_name: String.t()
        }

  @doc """
  The closed registry of all 33 `Ex4pmEngine.Wasm.*` adapters -- one entry per
  `<algo>_v1`/`<algo>_replay_v1` export pair the `wasm4pm-ex4pm-bindings` crate
  exposes. Delegates to the GENERATED `Ex4pmEngine.Wasm.AlgoRegistry` (source:
  `priv/ontology/ex4pm.ttl` plus the vendored bindings pack), so there is one
  registry, not two. The generated `:standing` key is dropped to keep this
  function's shape unchanged for existing consumers.
  """
  @spec algo_specs() :: [algo_spec()]
  def algo_specs do
    Enum.map(
      Ex4pmEngine.Wasm.AlgoRegistry.algo_specs(),
      &Map.take(&1, [:module, :algorithm_id, :export_name, :replay_export_name])
    )
  end

  @doc """
  Boots ONE real `Wasmex` instance from `artifact_path` (via `start/2`) and
  builds all 33 `default_transport/2` closures against it in one pass --
  the option map every `Ex4pmEngine.Wasm.*` adapter's `execute/3` expects
  under its own `:<algo>_wasm_fun` key, ready to `Keyword.merge` into an
  `execute/3` `opts` list or into a Reactor step's own transport-selection.
  Returns `{:ok, transports}` where `transports` is a keyword list
  `[discover_wasm_fun: fun, conform_wasm_fun: fun, ...]`, or `{:error,
  reason}` if the artifact can't be admitted or loaded. `start_opts` are
  forwarded to `start/2`.
  """
  @spec all_transports(String.t(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def all_transports(artifact_path, start_opts \\ []) do
    with {:ok, instance} <- start(artifact_path, start_opts) do
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
  Real end-to-end call against export `export_name` on an already-started
  `instance`, marshaling `request` (a plain map, JSON-encoded here) through
  the crate's real ptr/len ABI. Returns `{:ok, response_map}` on a decoded
  JSON object response, otherwise `{:error, %Ex4pm.Refusal{}}` with code one
  of `:invalid_encoding`, `:resource_limit`, `:abi_failure`, `:call_trapped`,
  `:call_timeout`, `:invalid_json`, `:malformed_response`. `response_map` is
  handed back verbatim to `Ex4pmEngine.Wasm.Adapter.accept/4`.

  Options: `:max_request_bytes` (default 16 MiB), `:max_response_bytes`
  (default 64 MiB; checked before the output is read), `:timeout` (ms).
  """
  @spec call(instance(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Refusal.t()}
  def call(%{pid: pid}, export_name, request, opts \\ []) when is_map(request) do
    guard(fn ->
      with {:ok, json} <- encode(request, opts),
           {:ok, store, memory} <- store_and_memory(pid) do
        with_buffer(pid, byte_size(json), fn in_ptr ->
          with :ok <- write(store, memory, in_ptr, json) do
            with_buffer(pid, 4, fn out_len_ptr ->
              invoke(pid, store, memory, export_name, in_ptr, byte_size(json), out_len_ptr, opts)
            end)
          end
        end)
      end
    end)
  end

  @doc """
  Real replay check: re-invokes `<algo>_replay_v1` (per the crate's own
  self-check contract) against the SAME request bytes and returns
  `{:ok, true | false}` for the export's `u32` return (exactly 1/0), else
  `{:error, %Ex4pm.Refusal{}}` (a result other than 0/1 is
  `:malformed_response`).
  """
  @spec replay(instance(), String.t(), map(), keyword()) ::
          {:ok, boolean()} | {:error, Refusal.t()}
  def replay(%{pid: pid}, replay_export_name, request, opts \\ []) when is_map(request) do
    guard(fn ->
      with {:ok, json} <- encode(request, opts),
           {:ok, store, memory} <- store_and_memory(pid) do
        with_buffer(pid, byte_size(json), fn in_ptr ->
          with :ok <- write(store, memory, in_ptr, json) do
            case Wasmex.call_function(
                   pid,
                   replay_export_name,
                   [in_ptr, byte_size(json)],
                   timeout(opts)
                 ) do
              {:ok, [0]} ->
                {:ok, false}

              {:ok, [1]} ->
                {:ok, true}

              {:ok, other} ->
                {:error,
                 refusal(:malformed_response, "replay result must be exactly 0 or 1", %{
                   result: inspect(other)
                 })}

              {:error, reason} ->
                {:error,
                 refusal(:call_trapped, "wasm replay trapped", %{
                   export: replay_export_name,
                   reason: inspect(reason)
                 })}
            end
          end
        end)
      end
    end)
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

  defp refusal(code, message, details), do: Refusal.new(code, message, details: details)

  # A dead/overloaded Wasmex GenServer exits the caller; surface a refusal instead.
  defp guard(fun) do
    fun.()
  catch
    :exit, {:timeout, _} = reason ->
      {:error, refusal(:call_timeout, "wasm call timed out", %{exit: inspect(reason)})}

    :exit, reason ->
      {:error, refusal(:call_trapped, "wasm instance unavailable", %{exit: inspect(reason)})}
  end

  defp timeout(opts), do: Keyword.get(opts, :timeout, @call_timeout_ms)

  defp encode(request, opts) do
    max = Keyword.get(opts, :max_request_bytes, @max_request_bytes)

    case Jason.encode(request) do
      {:ok, json} when byte_size(json) > max ->
        {:error,
         refusal(:resource_limit, "request exceeds max_request_bytes", %{
           limit: max,
           actual: byte_size(json)
         })}

      {:ok, json} ->
        {:ok, json}

      {:error, error} ->
        {:error,
         refusal(:invalid_encoding, "request is not encodable as UTF-8 JSON", %{
           error: inspect(error)
         })}
    end
  rescue
    error ->
      {:error,
       refusal(:invalid_encoding, "request is not encodable as UTF-8 JSON", %{
         error: inspect(error)
       })}
  end

  defp store_and_memory(pid) do
    with {:ok, store} <- Wasmex.store(pid),
         {:ok, memory} <- Wasmex.memory(pid) do
      {:ok, store, memory}
    else
      other ->
        {:error,
         refusal(:abi_failure, "wasm store/memory unavailable", %{result: inspect(other)})}
    end
  end

  defp write(store, memory, ptr, bytes) do
    case Wasmex.Memory.write_binary(store, memory, ptr, bytes) do
      :ok ->
        :ok

      other ->
        {:error,
         refusal(:abi_failure, "writing request into wasm memory failed", %{
           result: inspect(other)
         })}
    end
  rescue
    error ->
      {:error,
       refusal(:abi_failure, "writing request into wasm memory failed", %{error: inspect(error)})}
  end

  # Allocates `len` bytes, runs `fun.(ptr)`, and ALWAYS deallocs (try/after) --
  # no leak when the algorithm export traps or the response is refused.
  defp with_buffer(pid, len, fun) do
    case alloc(pid, len) do
      {:ok, ptr} ->
        try do
          fun.(ptr)
        after
          safe_dealloc(pid, ptr, len)
        end

      {:error, _} = error ->
        error
    end
  end

  defp invoke(pid, store, memory, export_name, in_ptr, in_len, out_len_ptr, opts) do
    max_out = Keyword.get(opts, :max_response_bytes, @max_response_bytes)

    case Wasmex.call_function(pid, export_name, [in_ptr, in_len, out_len_ptr], timeout(opts)) do
      {:ok, [out_ptr]} when is_integer(out_ptr) ->
        with {:ok, <<out_len::little-unsigned-32>>} <- read(store, memory, out_len_ptr, 4) do
          result = read_response(store, memory, out_ptr, out_len, max_out)

          case {result, free_output(pid, out_ptr, out_len)} do
            {{:ok, _} = ok, :ok} -> ok
            {{:ok, _}, {:error, _} = free_error} -> free_error
            {error, _} -> error
          end
        else
          {:ok, other} ->
            {:error,
             refusal(:abi_failure, "out_len buffer is not 4 bytes", %{result: inspect(other)})}

          {:error, _} = error ->
            error
        end

      {:ok, other} ->
        {:error,
         refusal(:malformed_response, "export must return exactly one i32 pointer", %{
           result: inspect(other)
         })}

      {:error, reason} ->
        {:error,
         refusal(:call_trapped, "wasm export trapped", %{
           export: export_name,
           reason: inspect(reason)
         })}
    end
  end

  defp read_response(_store, _memory, _ptr, len, max) when len > max do
    {:error,
     refusal(:resource_limit, "response exceeds max_response_bytes", %{limit: max, actual: len})}
  end

  defp read_response(store, memory, ptr, len, _max) do
    with {:ok, bytes} <- read_output(store, memory, ptr, len) do
      decode_response(bytes)
    end
  end

  defp read(store, memory, ptr, len) do
    case Wasmex.Memory.read_binary(store, memory, ptr, len) do
      bytes when is_binary(bytes) ->
        {:ok, bytes}

      other ->
        {:error, refusal(:abi_failure, "reading wasm memory failed", %{result: inspect(other)})}
    end
  rescue
    error ->
      {:error, refusal(:abi_failure, "reading wasm memory failed", %{error: inspect(error)})}
  end

  defp read_output(_store, _memory, _ptr, 0), do: {:ok, ""}
  defp read_output(store, memory, ptr, len), do: read(store, memory, ptr, len)

  defp decode_response(bytes) do
    if String.valid?(bytes) do
      case Jason.decode(bytes) do
        {:ok, map} when is_map(map) ->
          {:ok, map}

        {:ok, other} ->
          {:error,
           refusal(:malformed_response, "response is not a JSON object", %{value: inspect(other)})}

        {:error, reason} ->
          {:error,
           refusal(:invalid_json, "response is not valid JSON", %{reason: inspect(reason)})}
      end
    else
      {:error, refusal(:invalid_encoding, "response is not valid UTF-8", %{})}
    end
  end

  defp alloc(pid, len) do
    {alloc_name, _free, _dealloc} = Admission.allocator_exports()

    case Wasmex.call_function(pid, alloc_name, [len]) do
      {:ok, [ptr]} when is_integer(ptr) and ptr >= 0 ->
        {:ok, ptr}

      other ->
        {:error, refusal(:abi_failure, "alloc_v1 failed", %{len: len, result: inspect(other)})}
    end
  end

  defp safe_dealloc(pid, ptr, len) do
    {_alloc, _free, dealloc_name} = Admission.allocator_exports()
    Wasmex.call_function(pid, dealloc_name, [ptr, len])
    :ok
  catch
    :exit, _ -> :ok
  end

  defp free_output(_pid, _ptr, 0), do: :ok

  defp free_output(pid, ptr, len) do
    {_alloc, free_name, _dealloc} = Admission.allocator_exports()

    case Wasmex.call_function(pid, free_name, [ptr, len]) do
      {:ok, _} -> :ok
      other -> {:error, refusal(:abi_failure, "free_v1 failed", %{result: inspect(other)})}
    end
  end

  # Stubs are derived from the admitted allowlist (single source of truth with
  # Admission). They only satisfy instantiation-time import resolution.
  defp stub_imports(allowlist) do
    Enum.reduce(allowlist, %{}, fn {namespace, name, params, results}, acc ->
      Map.update(
        acc,
        namespace,
        %{name => stub_fn(params, results)},
        &Map.put(&1, name, stub_fn(params, results))
      )
    end)
  end

  defp zero_of(:i32), do: 0
  defp zero_of(:i64), do: 0
  defp zero_of(:f32), do: 0.0
  defp zero_of(:f64), do: 0.0

  defp stub_fn(params, []), do: {:fn, params, [], stub_body(length(params), nil)}

  defp stub_fn(params, [result_type]),
    do: {:fn, params, [result_type], stub_body(length(params), zero_of(result_type))}

  # Admitted imports have 0-3 params and 0-1 results; a wider signature would
  # have to be added to the manifest AND here.
  defp stub_body(0, ret), do: fn _ctx -> ret end
  defp stub_body(1, ret), do: fn _ctx, _a -> ret end
  defp stub_body(2, ret), do: fn _ctx, _a, _b -> ret end
  defp stub_body(3, ret), do: fn _ctx, _a, _b, _c -> ret end
end
