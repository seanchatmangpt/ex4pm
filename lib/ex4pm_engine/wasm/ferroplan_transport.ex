defmodule Ex4pmEngine.Wasm.FerroplanTransport do
  @moduledoc """
  Wasmex host for the ferroplan WASI linear-memory JSON ABI
  (`ferroplan/crates/ferroplan-wasm/src/wasi_abi.rs`).

  Wire sequence per `call/4`: JSON-encode `%{"op" => op, ...request}`;
  `fp_alloc(len) -> ptr`; write the UTF-8 bytes; `fp_call(ptr, len) ->` packed
  u64 `(out_ptr << 32) | out_len` (wasmex yields a signed i64, masked here);
  read the response; `fp_dealloc(out_ptr, out_len)` the RESPONSE buffer only
  (`fp_call` consumes the request buffer).

  The artifact is admitted by `Ex4pmEngine.Wasm.Admission` before any
  instance exists. The import allowlist is the `wasi_snapshot_preview1`
  imports the module declares; an import from any other module is refused
  (`:wasm_import_surface_mismatch`). Required exports: `fp_alloc fp_call
  fp_dealloc memory`.

  Pin: `opts[:expected_sha256]` (hex or `:unpinned`), else
  `priv/ferroplan/MANIFEST.json` `artifact.sha256`, else fail closed.

  Refusal codes beyond Admission's: `:ferroplan_artifact_unreadable`,
  `:ferroplan_instantiation_failed`, `:ferroplan_encoding_failed`,
  `:ferroplan_abi_failure`, `:ferroplan_call_timeout`,
  `:ferroplan_bad_response` (response bytes are not valid JSON), and
  `:ferroplan_engine_error` (ABI error envelope; `details` carries `code`,
  `message`, `retryable`). A timeout or trap stops the instance (the guest
  builds with `panic = "abort"`).

  Response shapes: any valid JSON is admitted. A JSON object is returned
  as-is, except an object whose only key is `"error"`, which is an engine
  error refusal. Any other valid JSON (array, `null`, string, number,
  boolean; e.g. `session_observe`, `session_elapse`, `session_suffix`,
  `session_step` answer with an array or `null`) is returned wrapped as
  `{:ok, %{"value" => json}}`.
  """

  import Bitwise

  alias Ex4pm.Refusal
  alias Ex4pmEngine.Wasm.Admission

  @wasi_module "wasi_snapshot_preview1"
  @required_exports ["fp_alloc", "fp_call", "fp_dealloc", "memory"]
  @default_timeout 30_000

  @manifest_path Path.expand("../../../priv/ferroplan/MANIFEST.json", __DIR__)

  @spec start(String.t(), keyword()) :: {:ok, pid()} | {:error, Refusal.t()}
  def start(artifact_path, opts \\ []) when is_binary(artifact_path) and is_list(opts) do
    with {:ok, bytes} <- read_artifact(artifact_path),
         {:ok, allowlist} <- wasi_allowlist(bytes),
         {:ok, admitted} <-
           Admission.admit(bytes,
             expected_sha256: pin(opts),
             import_allowlist: allowlist,
             required_exports: @required_exports
           ) do
      instantiate(admitted)
    end
  end

  @doc """
  One ABI call. Returns `{:ok, object}` for object responses and
  `{:ok, %{"value" => json}}` for non-object JSON (array, null, scalar); an
  object whose only key is `"error"` is `{:error, :ferroplan_engine_error}`;
  unparseable response bytes are `{:error, :ferroplan_bad_response}`.
  """
  @spec call(pid(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, Refusal.t()}
  def call(pid, op, request \\ %{}, opts \\ [])
      when is_pid(pid) and is_binary(op) and is_map(request) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    with {:ok, data} <- encode(Map.put(request, "op", op)),
         {:ok, store, memory} <- store_and_memory(pid),
         {:ok, ptr} <- alloc(pid, byte_size(data), timeout),
         :ok <- write(pid, store, memory, ptr, data, timeout),
         {:ok, packed} <- call_export(pid, "fp_call", [ptr, byte_size(data)], timeout) do
      read_response(pid, store, memory, packed, timeout)
    end
  rescue
    error ->
      {:error,
       Refusal.new(:ferroplan_abi_failure, "ferroplan call raised",
         details: %{error: Exception.message(error)}
       )}
  end

  @spec stop(pid()) :: :ok
  def stop(pid) when is_pid(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5_000)
    :ok
  catch
    :exit, _ -> :ok
  end

  # -- start helpers ---------------------------------------------------------

  defp read_artifact(path) do
    case File.read(path) do
      {:ok, bytes} ->
        {:ok, bytes}

      {:error, posix} ->
        {:error,
         Refusal.new(:ferroplan_artifact_unreadable, "cannot read ferroplan wasm artifact",
           details: %{path: path, reason: posix}
         )}
    end
  end

  defp pin(opts) do
    case Keyword.fetch(opts, :expected_sha256) do
      {:ok, pin} -> pin
      :error -> manifest_sha256()
    end
  end

  defp manifest_sha256 do
    with {:ok, raw} <- File.read(@manifest_path),
         {:ok, json} <- Jason.decode(raw) do
      get_in(json, ["artifact", "sha256"])
    else
      _ -> nil
    end
  end

  # The allowlist is exactly the WASI preview1 imports the module declares.
  # Imports from any other module stay outside it and are refused by Admission.
  defp wasi_allowlist(bytes) do
    with {:ok, store} <- Wasmex.Store.new(),
         {:ok, module} <- Wasmex.Module.compile(store, bytes) do
      list =
        for {@wasi_module, items} <- Wasmex.Module.imports(module),
            {name, {:fn, params, results}} <- items do
          {@wasi_module, name, params, results}
        end

      {:ok, list}
    else
      error ->
        {:error,
         Refusal.new(:wasm_invalid, "wasm module failed to compile",
           details: %{reason: inspect(error)}
         )}
    end
  end

  defp instantiate(admitted) do
    with {:ok, store} <- Wasmex.Store.new_wasi(%Wasmex.Wasi.WasiOptions{}, nil, admitted.engine),
         {:ok, pid} <- Wasmex.start_link(%{store: store, module: admitted.module}) do
      {:ok, pid}
    else
      error ->
        {:error,
         Refusal.new(:ferroplan_instantiation_failed, "ferroplan wasm failed to instantiate",
           details: %{reason: inspect(error)}
         )}
    end
  end

  # -- call helpers ----------------------------------------------------------

  defp encode(map) do
    {:ok, Jason.encode!(map)}
  rescue
    error ->
      {:error,
       Refusal.new(:ferroplan_encoding_failed, "request is not JSON-encodable",
         details: %{error: Exception.message(error)}
       )}
  end

  defp store_and_memory(pid) do
    with {:ok, store} <- Wasmex.store(pid),
         {:ok, memory} <- Wasmex.memory(pid) do
      {:ok, store, memory}
    else
      other ->
        {:error,
         Refusal.new(:ferroplan_abi_failure, "wasm store/memory unavailable",
           details: %{result: inspect(other)}
         )}
    end
  end

  defp alloc(pid, len, timeout) do
    with {:ok, [raw]} <- call_export(pid, "fp_alloc", [len], timeout) do
      case band(raw, 0xFFFF_FFFF) do
        0 -> {:error, Refusal.new(:ferroplan_abi_failure, "fp_alloc returned a null pointer")}
        ptr -> {:ok, ptr}
      end
    end
  end

  defp write(pid, store, memory, ptr, data, timeout) do
    case Wasmex.Memory.write_binary(store, memory, ptr, data) do
      :ok ->
        :ok

      other ->
        _ = call_export(pid, "fp_dealloc", [ptr, byte_size(data)], timeout)

        {:error,
         Refusal.new(:ferroplan_abi_failure, "writing request into guest memory failed",
           details: %{result: inspect(other)}
         )}
    end
  end

  defp call_export(pid, export, args, timeout) do
    case Wasmex.call_function(pid, export, args, timeout) do
      {:ok, results} ->
        case {export, results} do
          {"fp_call", [packed]} -> {:ok, packed}
          _ -> {:ok, results}
        end

      {:error, reason} ->
        {:error,
         Refusal.new(:ferroplan_abi_failure, "#{export} failed",
           details: %{reason: inspect(reason)}
         )}
    end
  catch
    :exit, reason ->
      stop(pid)

      {:error,
       Refusal.new(:ferroplan_call_timeout, "#{export} exited or timed out; instance discarded",
         details: %{reason: inspect(reason), engine_restarted: true}
       )}
  end

  defp read_response(pid, store, memory, packed, timeout) do
    packed = band(packed, 0xFFFF_FFFF_FFFF_FFFF)
    out_ptr = bsr(packed, 32)
    out_len = band(packed, 0xFFFF_FFFF)

    out = Wasmex.Memory.read_binary(store, memory, out_ptr, out_len)
    _ = call_export(pid, "fp_dealloc", [out_ptr, out_len], timeout)

    decode_response(out)
  end

  @doc """
  Pure decode of ferroplan response bytes (see the moduledoc for the shapes).
  """
  @spec decode_response(binary()) :: {:ok, map()} | {:error, Refusal.t()}
  def decode_response(out) when is_binary(out) do
    case Jason.decode(out) do
      {:ok, %{"error" => err} = decoded} when map_size(decoded) == 1 ->
        {:error, engine_refusal(err)}

      {:ok, %{} = decoded} ->
        {:ok, decoded}

      {:ok, other} ->
        {:ok, %{"value" => other}}

      {:error, error} ->
        {:error,
         Refusal.new(:ferroplan_bad_response, "response is not valid JSON",
           details: %{error: Exception.message(error), bytes: byte_size(out)}
         )}
    end
  end

  defp engine_refusal(%{} = err) do
    Refusal.new(:ferroplan_engine_error, to_string(err["message"] || "engine error"),
      details: %{
        code: err["code"],
        message: err["message"],
        retryable: err["retryable"] == true
      }
    )
  end

  defp engine_refusal(other),
    do: Refusal.new(:ferroplan_engine_error, "engine error", details: %{raw: inspect(other)})
end
