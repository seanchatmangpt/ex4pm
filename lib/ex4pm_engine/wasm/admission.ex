defmodule Ex4pmEngine.Wasm.Admission do
  @moduledoc """
  Admission court for `wasm4pm-ex4pm-bindings` artifact bytes: judged BEFORE
  any instance is started. Hand port of the QRI beam-host admission
  discipline (`ggen-marketplace/packs/qri-qualification-profile-pack/
  templates/beam-host/engine_load.ex.tmpl`), adapted to ex4pm's own ABI
  (`<algo>_v1(ptr,len,*out_len)->ptr`, `alloc_v1/free_v1/dealloc_v1`,
  `<algo>_replay_v1`) which the generated QRI host refuses.

  Mirrored QRI lines:

    * l.88 / l.126-136 -- `admit/2` judges bytes: digest pin, compile,
      import surface, required exports; telemetry emitted on every verdict
      (l.99 `@event [... :engine, :admit]`).
    * l.164-166 -- `expected_sha256: hex | :unpinned | nil`; `nil` fails
      closed.
    * l.174-182 -- digest check first, then compile, imports, exports; only
      a fully admitted `{engine, module}` is cached in `:persistent_term`.
    * l.229-261 -- imports judged against an allowlist; an unavailable or
      empty allowlist admits NOTHING (never allow-all).

  Deliberate deviation: the cache key is the digest PLUS a fingerprint of the
  allowlist and required-export set, so a cached admission can never satisfy
  a caller that asked for a stricter surface.

  The import allowlist is the `host_abi.imports` list of
  `priv/wasm4pm/MANIFEST.json` (embedded at compile time). `Ex4pmEngine.Wasm.
  RealTransport` derives its instantiation stubs from the same list, so the
  allowlist and the stubs cannot drift.

  ## Options

    * `:expected_sha256` -- hex digest (optionally `sha256:`-prefixed) or
      the explicit atom `:unpinned`. Absent / `nil` is refused
      (`:wasm_digest_unpinned`).
    * `:import_allowlist` -- override; list of `%{module:, name:, params:,
      results:}` maps or `{module, name, params, results}` tuples. `[]`
      means no imports are allowed.
    * `:required_exports` -- override list of export names.

  ## Refusal codes

  `:wasm_digest_unpinned`, `:wasm_digest_mismatch` (`details.expected`,
  `details.actual`), `:wasm_invalid`, `:wasm_import_surface_mismatch`
  (`details.unexpected`, `details.mismatched`), `:wasm_missing_export`
  (`details.missing`).
  """

  alias Ex4pm.Refusal

  @manifest_path Path.expand("../../../priv/wasm4pm/MANIFEST.json", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> Jason.decode!()

  @event [:ex4pm, :wasm, :admit]
  @wasm_magic <<0, "asm">>

  @alloc "wasm4pm_ex4pm_bindings_alloc_v1"
  @free "wasm4pm_ex4pm_bindings_free_v1"
  @dealloc "wasm4pm_ex4pm_bindings_dealloc_v1"

  @type import_spec :: {String.t(), String.t(), [atom()], [atom()]}
  @type admitted :: %{
          sha256: String.t(),
          engine: Wasmex.Engine.t(),
          module: Wasmex.Module.t(),
          allowlist: [import_spec()]
        }

  @doc "The decoded `priv/wasm4pm/MANIFEST.json`."
  @spec manifest() :: map()
  def manifest, do: @manifest

  @doc "Manifest-pinned artifact SHA-256 (hex) or `nil` when not yet pinned."
  @spec manifest_sha256() :: String.t() | nil
  def manifest_sha256, do: get_in(@manifest, ["artifact", "sha256"])

  @doc "Import allowlist from `host_abi.imports`; missing/empty => `[]` (no imports allowed)."
  @spec import_allowlist() :: [import_spec()]
  def import_allowlist do
    @manifest |> get_in(["host_abi", "imports"]) |> List.wrap() |> Enum.map(&normalize_spec/1)
  end

  @doc "Default required exports: allocator trio, memory, and every algo export + replay export."
  @spec required_exports() :: [String.t()]
  def required_exports do
    algo =
      Enum.flat_map(Ex4pmEngine.Wasm.RealTransport.algo_specs(), fn spec ->
        [spec.export_name, spec.replay_export_name]
      end)

    ["memory", @alloc, @free, @dealloc | algo]
  end

  @doc "Allocator export names `{alloc, free, dealloc}` of the ex4pm ABI."
  @spec allocator_exports() :: {String.t(), String.t(), String.t()}
  def allocator_exports, do: {@alloc, @free, @dealloc}

  @doc "Judges `bytes`; `{:ok, admitted}` or `{:error, %Ex4pm.Refusal{}}`."
  @spec admit(binary(), keyword()) :: {:ok, admitted()} | {:error, Refusal.t()}
  def admit(bytes, opts \\ []) when is_binary(bytes) and is_list(opts) do
    started = System.monotonic_time()
    hex = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

    allowlist =
      case Keyword.get(opts, :import_allowlist) do
        nil -> import_allowlist()
        list when is_list(list) -> Enum.map(list, &normalize_spec/1)
      end

    required = Keyword.get(opts, :required_exports) || required_exports()

    result =
      with :ok <- check_digest(hex, Keyword.get(opts, :expected_sha256)) do
        key = cache_key(hex, allowlist, required)

        case :persistent_term.get(key, nil) do
          %{} = entry -> {:ok, entry}
          nil -> compile_and_admit(hex, bytes, allowlist, required, key)
        end
      end

    emit(hex, result, started)
    result
  end

  @doc "Drops every cached admission (tests / deliberate re-admission)."
  @spec purge_cache() :: :ok
  def purge_cache do
    for {{__MODULE__, :admitted, _, _} = key, _} <- :persistent_term.get() do
      :persistent_term.erase(key)
    end

    :ok
  end

  # -- digest pin (FIRST) --------------------------------------------------

  defp check_digest(_hex, :unpinned), do: :ok

  defp check_digest(hex, expected) when is_binary(expected) do
    normalized = expected |> String.replace_prefix("sha256:", "") |> String.downcase()

    if normalized == hex do
      :ok
    else
      {:error,
       Refusal.new(:wasm_digest_mismatch, "wasm artifact digest does not match the pin",
         details: %{expected: normalized, actual: hex}
       )}
    end
  end

  defp check_digest(_hex, _nil_or_other) do
    {:error,
     Refusal.new(
       :wasm_digest_unpinned,
       "no wasm digest pin: pass expected_sha256: <hex> or the explicit :unpinned (fail closed)",
       details: %{}
     )}
  end

  # -- compile, imports, exports -------------------------------------------

  defp compile_and_admit(hex, bytes, allowlist, required, key) do
    with :ok <- check_magic(bytes),
         {:ok, engine, module} <- compile(bytes),
         :ok <- check_imports(Wasmex.Module.imports(module), allowlist),
         :ok <- check_exports(Wasmex.Module.exports(module), required) do
      entry = %{sha256: "sha256:" <> hex, engine: engine, module: module, allowlist: allowlist}
      :persistent_term.put(key, entry)
      {:ok, entry}
    end
  end

  # Wasmex.Module.compile/2 also accepts WAT text; the court admits binary wasm only.
  defp check_magic(<<@wasm_magic, _::binary>>), do: :ok

  defp check_magic(_),
    do: {:error, Refusal.new(:wasm_invalid, "artifact is not a binary wasm module (bad magic)")}

  defp compile(bytes) do
    engine = Wasmex.Engine.default()

    with {:ok, store} <- Wasmex.Store.new(nil, engine),
         {:ok, module} <- Wasmex.Module.compile(store, bytes) do
      {:ok, engine, module}
    else
      {:error, reason} ->
        {:error,
         Refusal.new(:wasm_invalid, "wasm module failed to compile",
           details: %{reason: inspect(reason)}
         )}
    end
  end

  defp check_imports(imports, allowlist) do
    allow = Map.new(allowlist, fn {m, n, p, r} -> {{m, n}, {:fn, p, r}} end)

    {unexpected, mismatched} =
      for {module, items} <- imports, {name, sig} <- items, reduce: {[], []} do
        {un, mis} ->
          label = "#{module}.#{name}"

          case Map.fetch(allow, {module, name}) do
            :error -> {[label | un], mis}
            {:ok, ^sig} -> {un, mis}
            {:ok, _other} -> {un, [label | mis]}
          end
      end

    if unexpected == [] and mismatched == [] do
      :ok
    else
      {:error,
       Refusal.new(:wasm_import_surface_mismatch, "wasm imports outside the allowlist",
         details: %{unexpected: Enum.sort(unexpected), mismatched: Enum.sort(mismatched)}
       )}
    end
  end

  defp check_exports(exports, required) do
    missing = Enum.reject(required, &Map.has_key?(exports, &1))

    if missing == [] do
      :ok
    else
      {:error,
       Refusal.new(:wasm_missing_export, "wasm module lacks required exports",
         details: %{missing: missing}
       )}
    end
  end

  # -- helpers ---------------------------------------------------------------

  defp cache_key(hex, allowlist, required) do
    fp =
      :crypto.hash(:sha256, :erlang.term_to_binary({allowlist, Enum.sort(required)}))
      |> Base.encode16(case: :lower)

    {__MODULE__, :admitted, hex, fp}
  end

  defp normalize_spec({m, n, p, r}), do: {to_string(m), to_string(n), types(p), types(r)}

  defp normalize_spec(%{} = map) do
    g = fn key -> Map.get(map, key) || Map.get(map, Atom.to_string(key)) end
    {to_string(g.(:module)), to_string(g.(:name)), types(g.(:params)), types(g.(:results))}
  end

  defp types(list), do: list |> List.wrap() |> Enum.map(&type/1)

  defp type(t) when t in [:i32, :i64, :f32, :f64, :v128], do: t
  defp type("i32"), do: :i32
  defp type("i64"), do: :i64
  defp type("f32"), do: :f32
  defp type("f64"), do: :f64
  defp type("v128"), do: :v128

  defp emit(hex, result, started) do
    {outcome, code} =
      case result do
        {:ok, _} -> {:admitted, nil}
        {:error, %Refusal{code: code}} -> {:refused, code}
      end

    :telemetry.execute(
      @event,
      %{duration: System.monotonic_time() - started},
      %{outcome: outcome, code: code, wasm_sha256: hex}
    )
  end
end
