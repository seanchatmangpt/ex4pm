defmodule Ex4pmEngine.Wasm.Adapter do
  @moduledoc """
  Shared `Ex4pm.Engine` implementation for the Phase-1
  `wasm4pm-ex4pm-bindings` algorithm exports (discover, conform, simulate,
  optimize, powl_mine).

  Mirrors `Ex4pm.Engine.CmcaWasm`'s six-state standing shape (inspection →
  native execution → WASM construction → WASM execution → replay → artifact
  identity) but is not BCINR-owned math, so there is no BCINR source pin —
  only the pinned `wasm4pm-ex4pm-bindings` crate source SHA. The transport is
  injected explicitly (`:"\#{algorithm_id}_wasm_fun"`, a 2-arity callback) so
  this adapter has no filesystem, scheduler, cloud, credential, or BRCE
  authority of its own — same discipline as `CmcaWasm`.

  `use Ex4pmEngine.Wasm.Adapter,
    algorithm_id: :discover,
    engine_id: :wasm_discover,
    wasm_export: "wasm4pm_ex4pm_discover_v1",
    wasm_replay_export: "wasm4pm_ex4pm_discover_replay_v1"`
  """

  # Updated 2026-08-27: pins wasm4pm commit 36b74c6a3a11689fea8a445c198089ef48ec5dea
  # ("feat(bindings): add alloc/dealloc exports closing the real host-write
  # gap"), which added `wasm4pm_ex4pm_bindings_alloc_v1`/`_dealloc_v1` -- the
  # allocator export the ptr/len ABI documented in
  # `~/wasm4pm/crates/wasm4pm-ex4pm-bindings/src/lib.rs` needed but never
  # had, and which `Ex4pmEngine.Wasm.RealTransport` now depends on to write
  # a real request buffer into the module's own linear memory before
  # calling any `<algo>_v1` export. A rebuild from the prior, unpinned SHA
  # has no allocator and cannot serve `RealTransport` at all.
  @wasm4pm_source_sha "36b74c6a3a11689fea8a445c198089ef48ec5dea"
  @protocol "wasm4pm.ex4pm-bindings/v1"

  def wasm4pm_source_sha, do: @wasm4pm_source_sha
  def protocol, do: @protocol

  defmacro __using__(opts) do
    algorithm_id = Keyword.fetch!(opts, :algorithm_id)
    engine_id = Keyword.fetch!(opts, :engine_id)
    wasm_export = Keyword.fetch!(opts, :wasm_export)
    wasm_replay_export = Keyword.fetch!(opts, :wasm_replay_export)
    transport_key = String.to_atom("#{algorithm_id}_wasm_fun")

    quote do
      @behaviour Ex4pm.Engine

      alias Ex4pm.Engine.Result
      alias Ex4pm.Refusal
      alias Ex4pmEngine.Wasm.Adapter

      @algorithm_id unquote(algorithm_id)
      @engine_id unquote(engine_id)
      @wasm_export unquote(wasm_export)
      @wasm_replay_export unquote(wasm_replay_export)
      @transport_key unquote(transport_key)
      @protocol Adapter.protocol()
      @wasm4pm_source_sha Adapter.wasm4pm_source_sha()

      @impl true
      def id, do: @engine_id

      @impl true
      def supports?(operation, _opts), do: operation == @algorithm_id

      @impl true
      def available?(opts), do: is_function(Keyword.get(opts, @transport_key), 2)

      @impl true
      def execute(operation, subject, opts) when operation == @algorithm_id and is_map(subject) do
        case Keyword.get(opts, @transport_key) do
          fun when is_function(fun, 2) ->
            case fun.(Adapter.json_term(subject), opts) do
              {:ok, response, identity} when is_map(response) ->
                Adapter.accept(response, identity, subject, %{
                  engine_id: @engine_id,
                  algorithm_id: @algorithm_id,
                  protocol: @protocol,
                  wasm_export: @wasm_export,
                  wasm_replay_export: @wasm_replay_export,
                  wasm4pm_source_sha: @wasm4pm_source_sha
                })

              {:ok, response} when is_map(response) ->
                Adapter.accept(response, nil, subject, %{
                  engine_id: @engine_id,
                  algorithm_id: @algorithm_id,
                  protocol: @protocol,
                  wasm_export: @wasm_export,
                  wasm_replay_export: @wasm_replay_export,
                  wasm4pm_source_sha: @wasm4pm_source_sha
                })

              response when is_map(response) ->
                Adapter.accept(response, nil, subject, %{
                  engine_id: @engine_id,
                  algorithm_id: @algorithm_id,
                  protocol: @protocol,
                  wasm_export: @wasm_export,
                  wasm_replay_export: @wasm_replay_export,
                  wasm4pm_source_sha: @wasm4pm_source_sha
                })

              {:error, %Refusal{} = refusal} ->
                {:error, refusal}

              {:error, reason} ->
                {:error,
                 Refusal.new(
                   :"#{@algorithm_id}_wasm_transport_failed",
                   "#{@algorithm_id} WASM transport failed",
                   details: %{reason: inspect(reason)}
                 )}

              other ->
                {:error,
                 Refusal.new(
                   :"invalid_#{@algorithm_id}_wasm_transport_result",
                   "#{@algorithm_id} WASM transport returned an invalid value",
                   details: %{result: inspect(other)}
                 )}
            end

          _ ->
            {:error,
             Refusal.new(
               :"#{@algorithm_id}_wasm_unavailable",
               "#{@algorithm_id} requires an explicit wasm4pm transport callback"
             )}
        end
      end

      def execute(operation, subject, _opts) when operation == @algorithm_id do
        {:error,
         Refusal.new(
           :"invalid_#{@algorithm_id}_problem",
           "#{@algorithm_id} requires a map request",
           subject: subject
         )}
      end

      def execute(operation, subject, _opts) do
        {:error,
         Refusal.new(
           :"unsupported_#{@algorithm_id}_wasm_operation",
           "#{@engine_id} only supports #{@algorithm_id}",
           subject: subject,
           details: %{operation: operation}
         )}
      end

      def protocol, do: @protocol
      def wasm4pm_source_sha, do: @wasm4pm_source_sha
      def wasm_export, do: @wasm_export
      def wasm_replay_export, do: @wasm_replay_export
    end
  end

  @doc false
  def accept(response, identity, subject, ctx) do
    receipt = field(response, :receipt)
    result = field(response, :result)

    with true <- field(response, :standing) in ["ALIVE", "PARTIAL_ALIVE"],
         true <- is_map(result),
         true <- is_map(receipt),
         true <- field(receipt, :schema) == ctx.protocol,
         true <- field(receipt, :algorithm_id) == to_string(ctx.algorithm_id),
         true <- field(receipt, :wasm_export) == ctx.wasm_export,
         :ok <- admit_source(receipt, ctx),
         request_hash when is_binary(request_hash) <- nonempty(field(receipt, :request_digest)),
         result_hash when is_binary(result_hash) <- nonempty(field(receipt, :result_digest)),
         :ok <- validate_observed_identity(identity, ctx) do
      observed? = exact_observed_identity?(identity, ctx)

      {:ok,
       %Ex4pm.Engine.Result{
         engine: ctx.engine_id,
         operation: ctx.algorithm_id,
         algorithm: ctx.algorithm_id,
         subject_hash: Ex4pm.Core.Hash.digest(subject),
         standing: if(observed?, do: :alive, else: :partial_alive),
         value: result,
         evidence: %{
           protocol: ctx.protocol,
           wasm4pm_source_sha: ctx.wasm4pm_source_sha,
           wasm_export: ctx.wasm_export,
           wasm_replay_export: ctx.wasm_replay_export,
           authority: :construct_only,
           actuation_performed: false,
           request_digest: request_hash,
           result_digest: result_hash,
           replay_verified: field(identity, :replay_verified) == true,
           transport_identity: identity,
           identity_observed: observed?,
           executed: true
         }
       }}
    else
      {:error, %Ex4pm.Refusal{} = refusal} ->
        {:error, refusal}

      _ ->
        {:error,
         Ex4pm.Refusal.new(
           :"invalid_#{ctx.algorithm_id}_wasm_response",
           "#{ctx.algorithm_id} WASM response failed protocol admission",
           subject: subject,
           details: %{
             standing: field(response, :standing),
             schema: field(receipt, :schema)
           }
         )}
    end
  end

  defp admit_source(receipt, ctx) do
    case field(receipt, :wasm4pm_source_sha) do
      sha when sha == ctx.wasm4pm_source_sha ->
        :ok

      observed ->
        {:error,
         Ex4pm.Refusal.new(
           :"#{ctx.algorithm_id}_source_identity_mismatch",
           "receipt does not bind the exact admitted wasm4pm-ex4pm-bindings source",
           details: %{expected: ctx.wasm4pm_source_sha, observed: observed}
         )}
    end
  end

  defp validate_observed_identity(identity, ctx) do
    cond do
      not observed_identity?(identity) ->
        :ok

      field(identity, :wasm4pm_source_sha) != ctx.wasm4pm_source_sha ->
        {:error,
         Ex4pm.Refusal.new(
           :"#{ctx.algorithm_id}_wasm_identity_mismatch",
           "observed wasm4pm source does not match the pinned wasm4pm-ex4pm-bindings head",
           details: %{
             expected: ctx.wasm4pm_source_sha,
             observed: field(identity, :wasm4pm_source_sha)
           }
         )}

      field(identity, :replay_verified) != true ->
        {:error,
         Ex4pm.Refusal.new(
           :"#{ctx.algorithm_id}_wasm_replay_unverified",
           "observed execution did not establish WASM export replay",
           details: %{observed: field(identity, :replay_verified)}
         )}

      true ->
        :ok
    end
  end

  defp exact_observed_identity?(identity, ctx) do
    observed_identity?(identity) and
      field(identity, :wasm4pm_source_sha) == ctx.wasm4pm_source_sha and
      field(identity, :replay_verified) == true and
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

  @doc false
  def json_term(value) when is_map(value) do
    Map.new(value, fn {key, nested} -> {to_string(key), json_term(nested)} end)
  end

  def json_term(value) when is_tuple(value),
    do: value |> Tuple.to_list() |> Enum.map(&json_term/1)

  def json_term(value) when is_list(value), do: Enum.map(value, &json_term/1)
  def json_term(value) when value in [true, false, nil], do: value
  def json_term(value) when is_atom(value), do: Atom.to_string(value)
  def json_term(value), do: value
end
