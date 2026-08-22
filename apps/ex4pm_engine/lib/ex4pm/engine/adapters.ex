defmodule Ex4pm.Engine.Wasm do
  @moduledoc "Wasmex-backed raw WebAssembly execution with an explicit ABI contract."

  @behaviour Ex4pm.Engine

  alias Ex4pm.Engine.Result
  alias Ex4pm.Refusal

  @impl true
  def id, do: :wasm

  @impl true
  def supports?(operation, opts) do
    contract = Keyword.get(opts, :wasm_contract, %{})
    Map.has_key?(contract, operation)
  end

  @impl true
  def available?(opts) do
    path = Keyword.get(opts, :wasm_path)
    is_binary(path) and File.regular?(path) and Code.ensure_loaded?(Wasmex)
  end

  @impl true
  def execute(operation, subject, opts) do
    path = Keyword.get(opts, :wasm_path)
    contract = Keyword.get(opts, :wasm_contract, %{}) |> Map.get(operation)

    with true <-
           available?(opts) ||
             {:error,
              Refusal.new(:wasm_unavailable, "configured WebAssembly artifact is unavailable",
                details: %{path: path}
              )},
         %{export: export} = abi <-
           contract ||
             {:error,
              Refusal.new(
                :missing_wasm_contract,
                "operation has no admitted WebAssembly ABI contract",
                details: %{operation: operation}
              )},
         {:ok, bytes} <- File.read(path),
         {:ok, pid} <- Wasmex.start_link(%{bytes: bytes}),
         params <- encode_params(abi, subject),
         {:ok, raw} <- Wasmex.call_function(pid, export, params, Map.get(abi, :timeout, 5_000)),
         {:ok, value} <- decode_result(abi, raw) do
      {:ok,
       %Result{
         engine: :wasm,
         operation: operation,
         algorithm: Map.get(abi, :algorithm, :external_wasm),
         subject_hash: subject_hash(subject),
         standing: :alive,
         value: value,
         evidence: %{
           artifact_hash: Ex4pm.Core.Hash.digest(bytes),
           export: export,
           abi_hash: Ex4pm.Core.Hash.digest(abi),
           runtime: :wasmex_wasmtime,
           executed: true
         }
       }}
    else
      {:error, %Refusal{} = refusal} ->
        {:error, refusal}

      {:error, reason} ->
        {:error,
         Refusal.new(:wasm_execution_failed, "WebAssembly execution failed",
           details: %{reason: inspect(reason)}
         )}

      other ->
        {:error,
         Refusal.new(:invalid_wasm_contract, "WebAssembly contract could not execute",
           details: %{result: inspect(other)}
         )}
    end
  end

  defp encode_params(%{encode: fun}, subject) when is_function(fun, 1), do: fun.(subject)
  defp encode_params(%{params: params}, _subject) when is_list(params), do: params
  defp encode_params(_abi, _subject), do: []

  defp decode_result(%{decode: fun}, raw) when is_function(fun, 1) do
    case fun.(raw) do
      {:ok, value} -> {:ok, value}
      value -> {:ok, value}
    end
  end

  defp decode_result(_abi, raw), do: {:ok, raw}

  defp subject_hash(%{subject: %{hash: hash}}), do: hash
  defp subject_hash(subject), do: Ex4pm.Core.Hash.digest(subject)
end

defmodule Ex4pm.Engine.Nif do
  @moduledoc "Configured native-engine candidate without hard-coding a Rustler implementation."

  @behaviour Ex4pm.Engine

  alias Ex4pm.Engine.Result
  alias Ex4pm.Refusal

  @impl true
  def id, do: :nif

  @impl true
  def supports?(operation, opts) do
    case Keyword.get(opts, :nif_module) do
      module when is_atom(module) -> function_exported?(module, operation, 2)
      _ -> false
    end
  end

  @impl true
  def available?(opts) do
    case Keyword.get(opts, :nif_module) do
      module when is_atom(module) -> Code.ensure_loaded?(module)
      _ -> false
    end
  end

  @impl true
  def execute(operation, subject, opts) do
    module = Keyword.get(opts, :nif_module)

    if available?(opts) and function_exported?(module, operation, 2) do
      case apply(module, operation, [subject, opts]) do
        {:ok, value} -> ok(operation, subject, value, module)
        {:error, reason} -> {:error, reason}
        value -> ok(operation, subject, value, module)
      end
    else
      {:error,
       Refusal.new(:nif_unavailable, "configured NIF module cannot execute operation",
         details: %{module: module, operation: operation}
       )}
    end
  end

  defp ok(operation, subject, value, module) do
    {:ok,
     %Result{
       engine: :nif,
       operation: operation,
       algorithm: :external_nif,
       subject_hash: Ex4pm.Core.Hash.digest(subject),
       standing: :partial_alive,
       value: value,
       evidence: %{module: module, executed: true, native_identity: :unproven}
     }}
  end
end

defmodule Ex4pm.Engine.Remote do
  @moduledoc "Explicit remote analytical engine callback candidate."

  @behaviour Ex4pm.Engine

  alias Ex4pm.Engine.Result
  alias Ex4pm.Refusal

  @impl true
  def id, do: :remote

  @impl true
  def supports?(_operation, opts), do: is_function(Keyword.get(opts, :remote_fun), 3)

  @impl true
  def available?(opts), do: supports?(:any, opts)

  @impl true
  def execute(operation, subject, opts) do
    case Keyword.get(opts, :remote_fun) do
      fun when is_function(fun, 3) ->
        case fun.(operation, subject, opts) do
          {:ok, value} -> ok(operation, subject, value)
          {:error, reason} -> {:error, reason}
          value -> ok(operation, subject, value)
        end

      _ ->
        {:error, Refusal.new(:remote_unavailable, "remote engine requires an explicit callback")}
    end
  end

  defp ok(operation, subject, value) do
    {:ok,
     %Result{
       engine: :remote,
       operation: operation,
       algorithm: :remote,
       subject_hash: Ex4pm.Core.Hash.digest(subject),
       standing: :partial_alive,
       value: value,
       evidence: %{executed: true, transport: :callback, remote_identity: :unproven}
     }}
  end
end
