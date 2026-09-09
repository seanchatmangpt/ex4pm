defmodule Ex4pm.Engine.Wasm do
  @moduledoc "Wasmex-backed raw WebAssembly execution with exact artifact admission."
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
         artifact_hash <- Ex4pm.Core.Hash.digest(bytes),
         :ok <- admit_digest(Keyword.get(opts, :wasm_digest), artifact_hash),
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
           artifact_hash: artifact_hash,
           export: export,
           abi_hash: Ex4pm.Core.Hash.digest(abi),
           runtime: :wasmex_wasmtime,
           runtime_identity: Keyword.get(opts, :wasm_runtime_identity, :observed_wasmex),
           exact_artifact: true,
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

  defp admit_digest(nil, _actual), do: :ok
  defp admit_digest(expected, actual) when expected == actual, do: :ok

  defp admit_digest(expected, actual),
    do:
      {:error,
       Refusal.new(
         :wasm_identity_mismatch,
         "WebAssembly artifact digest does not match admitted subject",
         details: %{expected: expected, observed: actual}
       )}

  defp encode_params(%{encode: fun}, subject) when is_function(fun, 1), do: fun.(subject)
  defp encode_params(%{params: params}, _subject) when is_list(params), do: params
  defp encode_params(_abi, _subject), do: []

  defp decode_result(%{decode: fun}, raw) when is_function(fun, 1),
    do:
      case(fun.(raw),
        do: (
          {:ok, value} -> {:ok, value}
          value -> {:ok, value}
        )
      )

  defp decode_result(_abi, raw), do: {:ok, raw}
  defp subject_hash(%{subject: %{hash: hash}}), do: hash
  defp subject_hash(subject), do: Ex4pm.Core.Hash.digest(subject)
end

defmodule Ex4pm.Engine.Nif do
  @moduledoc "Configured native-engine candidate with exact library identity admission."
  @behaviour Ex4pm.Engine

  alias Ex4pm.Engine.Result
  alias Ex4pm.Refusal

  @impl true
  def id, do: :nif
  @impl true
  def supports?(operation, opts),
    do:
      case(Keyword.get(opts, :nif_module),
        do: (
          module when is_atom(module) -> function_exported?(module, operation, 2)
          _ -> false
        )
      )

  @impl true
  def available?(opts),
    do:
      case(Keyword.get(opts, :nif_module),
        do: (
          module when is_atom(module) -> Code.ensure_loaded?(module)
          _ -> false
        )
      )

  @impl true
  def execute(operation, subject, opts) do
    module = Keyword.get(opts, :nif_module)
    identity = Keyword.get(opts, :nif_identity)

    with true <-
           (available?(opts) and function_exported?(module, operation, 2)) ||
             {:error,
              Refusal.new(:nif_unavailable, "configured NIF module cannot execute operation",
                details: %{module: module, operation: operation}
              )},
         :ok <- admit_identity(identity, Keyword.get(opts, :nif_digest)) do
      case apply(module, operation, [subject, opts]) do
        {:ok, value} -> ok(operation, subject, value, module, identity)
        {:error, reason} -> {:error, reason}
        value -> ok(operation, subject, value, module, identity)
      end
    end
  end

  defp ok(operation, subject, value, module, identity) do
    exact? = exact_identity?(identity)

    {:ok,
     %Result{
       engine: :nif,
       operation: operation,
       algorithm: :external_nif,
       subject_hash: Ex4pm.Core.Hash.digest(subject),
       standing: if(exact?, do: :alive, else: :partial_alive),
       value: value,
       evidence: %{
         module: module,
         executed: true,
         native_identity: identity || :unproven,
         exact_artifact: exact?
       }
     }}
  end

  defp admit_identity(nil, nil), do: :ok
  defp admit_identity(identity, nil) when is_map(identity), do: :ok

  defp admit_identity(identity, expected) when is_map(identity) do
    observed = field(identity, :library_digest)

    if observed == expected,
      do: :ok,
      else:
        {:error,
         Refusal.new(:nif_identity_mismatch, "NIF library digest does not match admitted subject",
           details: %{expected: expected, observed: observed}
         )}
  end

  defp admit_identity(_identity, expected),
    do:
      {:error,
       Refusal.new(:nif_identity_mismatch, "NIF exact identity is missing",
         details: %{expected: expected}
       )}

  defp exact_identity?(identity) do
    is_map(identity) and field(identity, :observed) == true and
      is_binary(field(identity, :source_sha)) and is_binary(field(identity, :library_digest)) and
      is_binary(field(identity, :toolchain))
  end

  defp field(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
end

defmodule Ex4pm.Engine.Remote do
  @moduledoc "Explicit authenticated remote analytical engine candidate."
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
          {:ok, value, identity} ->
            with(
              :ok <- admit_identity(identity, Keyword.get(opts, :remote_image_digest)),
              do: ok(operation, subject, value, identity)
            )

          {:ok, value} ->
            ok(operation, subject, value, nil)

          {:error, reason} ->
            {:error, reason}

          value ->
            ok(operation, subject, value, nil)
        end

      _ ->
        {:error, Refusal.new(:remote_unavailable, "remote engine requires an explicit callback")}
    end
  end

  defp ok(operation, subject, value, identity) do
    exact? = exact_identity?(identity)

    {:ok,
     %Result{
       engine: :remote,
       operation: operation,
       algorithm: :remote,
       subject_hash: Ex4pm.Core.Hash.digest(subject),
       standing: if(exact?, do: :alive, else: :partial_alive),
       value: value,
       evidence: %{
         executed: true,
         transport: if(identity, do: field(identity, :transport), else: :callback),
         remote_identity: identity || :unproven,
         exact_artifact: exact?
       }
     }}
  end

  defp admit_identity(identity, nil) when is_map(identity), do: :ok
  defp admit_identity(nil, nil), do: :ok

  defp admit_identity(identity, expected) when is_map(identity) do
    observed = field(identity, :image_digest)

    if observed == expected,
      do: :ok,
      else:
        {:error,
         Refusal.new(
           :remote_identity_mismatch,
           "remote image digest does not match admitted subject",
           details: %{expected: expected, observed: observed}
         )}
  end

  defp admit_identity(_identity, expected),
    do:
      {:error,
       Refusal.new(:remote_identity_mismatch, "remote exact identity is missing",
         details: %{expected: expected}
       )}

  defp exact_identity?(identity) do
    is_map(identity) and field(identity, :observed) == true and
      field(identity, :transport) in [:tls, :https, :mtls, "tls", "https", "mtls"] and
      is_binary(field(identity, :source_sha)) and is_binary(field(identity, :image_digest)) and
      field(identity, :receipt_verified) == true
  end

  defp field(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
end
