defmodule Ex4pm.Engine.CmcaWasm do
  @moduledoc """
  Analytical adapter for the exact BCINR CMCA kernel exported through wasm4pm.

  CMCA is a consequence-allocation computation upstream of selection and DO. The
  transport is injected explicitly so this adapter has no filesystem, scheduler,
  cloud, credential, or BRCE authority. A result reaches `:alive` only when the
  response binds the exact BCINR source and construct-only receipt contract and
  the transport reports the exact wasm4pm source plus an observed WASM digest.
  """

  @behaviour Ex4pm.Engine

  alias Ex4pm.Engine.Result
  alias Ex4pm.Refusal

  @protocol "wasm4pm.cmca-allocation/v1"
  @bcinr_source_sha "b76dcb377b297cb8826a5256b55f8b57a6b76462"
  @bcinr_package "bcinr-cmca"
  @bcinr_version "26.7.28"
  @kernel "bcinr_cmca::allocator::allocate_single_lens"
  @wasm4pm_source_sha "b27bfed6290285e76fb03db9c404c6d627377b6e"
  @authority "CONSTRUCT_ONLY"

  @impl true
  def id, do: :cmca_wasm

  @impl true
  def supports?(:cmca, _opts), do: true
  def supports?(_operation, _opts), do: false

  @impl true
  def available?(opts), do: is_function(Keyword.get(opts, :cmca_wasm_fun), 2)

  @impl true
  def execute(:cmca, subject, opts) when is_map(subject) do
    case Keyword.get(opts, :cmca_wasm_fun) do
      fun when is_function(fun, 2) ->
        case fun.(json_term(subject), opts) do
          {:ok, response, identity} when is_map(response) ->
            accept(response, identity, subject)

          {:ok, response} when is_map(response) ->
            accept(response, nil, subject)

          response when is_map(response) ->
            accept(response, nil, subject)

          {:error, %Refusal{} = refusal} ->
            {:error, refusal}

          {:error, reason} ->
            {:error,
             Refusal.new(:cmca_wasm_transport_failed, "CMCA WASM transport failed",
               details: %{reason: inspect(reason)}
             )}

          other ->
            {:error,
             Refusal.new(:invalid_cmca_wasm_transport_result, "CMCA WASM transport returned an invalid value",
               details: %{result: inspect(other)}
             )}
        end

      _ ->
        {:error,
         Refusal.new(:cmca_wasm_unavailable, "CMCA requires an explicit wasm4pm transport callback")}
    end
  end

  def execute(:cmca, subject, _opts) do
    {:error,
     Refusal.new(:invalid_cmca_problem, "CMCA requires a map consequence-allocation request",
       subject: subject
     )}
  end

  def execute(operation, subject, _opts) do
    {:error,
     Refusal.new(:unsupported_cmca_wasm_operation, "CMCA WASM only supports consequence allocation",
       subject: subject,
       details: %{operation: operation}
     )}
  end

  def protocol, do: @protocol
  def bcinr_source_sha, do: @bcinr_source_sha
  def wasm4pm_source_sha, do: @wasm4pm_source_sha
  def kernel, do: @kernel

  defp accept(response, identity, subject) do
    receipt = field(response, :receipt)
    result = field(response, :result)

    with true <- field(response, :standing) == "ALIVE",
         true <- is_map(result),
         true <- is_map(receipt),
         true <- field(receipt, :schema) == @protocol,
         :ok <- admit_cmca_source(receipt),
         true <- field(receipt, :bcinr_package) == @bcinr_package,
         true <- field(receipt, :bcinr_version) == @bcinr_version,
         true <- field(receipt, :kernel) == @kernel,
         true <- field(receipt, :authority) == @authority,
         true <- field(receipt, :actuation_performed) == false,
         request_hash when is_binary(request_hash) <- nonempty(field(receipt, :request_blake3)),
         result_hash when is_binary(result_hash) <- nonempty(field(receipt, :result_blake3)),
         receipt_hash when is_binary(receipt_hash) <- nonempty(field(receipt, :receipt_blake3)),
         :ok <- validate_observed_identity(identity) do
      observed? = exact_observed_identity?(identity)

      {:ok,
       %Result{
         engine: :cmca_wasm,
         operation: :cmca,
         algorithm: :consequence_allocation,
         subject_hash: Ex4pm.Core.Hash.digest(subject),
         standing: if(observed?, do: :alive, else: :partial_alive),
         value: result,
         evidence: %{
           protocol: @protocol,
           bcinr_source_sha: @bcinr_source_sha,
           bcinr_package: @bcinr_package,
           bcinr_version: @bcinr_version,
           kernel: @kernel,
           authority: :construct_only,
           actuation_performed: false,
           request_blake3: request_hash,
           result_blake3: result_hash,
           cmca_receipt_blake3: receipt_hash,
           transport_identity: identity,
           identity_observed: observed?,
           executed: true
         }
       }}
    else
      {:error, %Refusal{} = refusal} ->
        {:error, refusal}

      _ ->
        {:error,
         Refusal.new(:invalid_cmca_wasm_response, "CMCA WASM response failed protocol admission",
           subject: subject,
           details: %{
             standing: field(response, :standing),
             schema: field(receipt, :schema),
             authority: field(receipt, :authority),
             actuation_performed: field(receipt, :actuation_performed)
           }
         )}
    end
  end

  defp admit_cmca_source(receipt) do
    case field(receipt, :bcinr_source_sha) do
      @bcinr_source_sha ->
        :ok

      observed ->
        {:error,
         Refusal.new(:cmca_source_identity_mismatch, "CMCA receipt does not bind the exact admitted BCINR source",
           details: %{expected: @bcinr_source_sha, observed: observed}
         )}
    end
  end

  defp validate_observed_identity(identity) do
    if observed_identity?(identity) and field(identity, :wasm4pm_source_sha) != @wasm4pm_source_sha do
      {:error,
       Refusal.new(:cmca_wasm_identity_mismatch, "observed wasm4pm source does not match the pinned CMCA export head",
         details: %{expected: @wasm4pm_source_sha, observed: field(identity, :wasm4pm_source_sha)}
       )}
    else
      :ok
    end
  end

  defp exact_observed_identity?(identity) do
    observed_identity?(identity) and
      field(identity, :wasm4pm_source_sha) == @wasm4pm_source_sha and
      is_binary(nonempty(field(identity, :wasm_sha256)))
  end

  defp observed_identity?(identity), do: is_map(identity) and field(identity, :observed) == true
  defp nonempty(value) when is_binary(value) and byte_size(value) > 0, do: value
  defp nonempty(_), do: nil

  defp field(map, key) when is_map(map) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Atom.to_string(key))
    end
  end

  defp field(_other, _key), do: nil

  defp json_term(value) when is_map(value) do
    Map.new(value, fn {key, nested} -> {to_string(key), json_term(nested)} end)
  end

  defp json_term(value) when is_tuple(value), do: value |> Tuple.to_list() |> Enum.map(&json_term/1)
  defp json_term(value) when is_list(value), do: Enum.map(value, &json_term/1)
  defp json_term(value) when value in [true, false, nil], do: value
  defp json_term(value) when is_atom(value), do: Atom.to_string(value)
  defp json_term(value), do: value
end
