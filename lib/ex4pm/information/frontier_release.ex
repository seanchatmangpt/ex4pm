defmodule Ex4pm.Information.FrontierRelease do
  @moduledoc """
  Deterministic process-intelligence primitives for Frontier Release Inversion.

  This module starts *after* semantic extraction. It does not fetch articles,
  call an LLM, create repositories, deploy systems, or publish releases. Its
  job is to turn already-normalized observations into bounded process facts
  and to calculate which working-backwards claims have enough exact-subject
  evidence to become earned claims.

  The authority invariant is intentionally simple:

      observation != opportunity != authority != execution != standing

  External DO remains outside this module and must pass through the owning
  BRCE/actuation boundary.
  """

  @response_modes ~w(reuse compose extend invent benchmark formalize automate eliminate)a
  @stages ~w(observe extract fence invert specify manufacture verify publish)a
  @stage_index @stages |> Enum.with_index() |> Map.new()

  @type refusal :: {:refused, atom(), map()}
  @type result(value) :: {:ok, value} | {:error, refusal()}

  @doc "Returns the ordered Frontier Release Factory lifecycle."
  @spec stages() :: [atom()]
  def stages, do: @stages

  @doc "Normalizes a source-release observation without granting it standing or authority."
  @spec normalize_observation(map()) :: result(map())
  def normalize_observation(attrs) when is_map(attrs) do
    with {:ok, source_url} <- required_string(attrs, :source_url),
         {:ok, publisher} <- required_string(attrs, :publisher),
         {:ok, published_at} <- normalize_datetime(value(attrs, :published_at)),
         {:ok, content_digest} <- required_string(attrs, :content_digest),
         {:ok, claims} <- normalize_claims(value(attrs, :claims, [])) do
      {:ok,
       %{
         source_url: source_url,
         publisher: publisher,
         published_at: published_at,
         content_digest: content_digest,
         claims: claims,
         standing: :observed,
         authority: :none
       }}
    end
  end

  def normalize_observation(value),
    do: refuse(:invalid_observation, %{expected: :map, got: inspect(value)})

  @doc "Builds a bounded candidate opportunity from a normalized observation."
  @spec qualify_opportunity(map(), map()) :: result(map())
  def qualify_opportunity(%{content_digest: source_digest} = observation, attrs)
      when is_map(attrs) and is_binary(source_digest) do
    with {:ok, response_mode} <- normalize_response_mode(value(attrs, :response_mode)),
         {:ok, target_repository} <- required_string(attrs, :target_repository),
         {:ok, required_capability} <- required_string(attrs, :required_capability),
         {:ok, benchmark} <- normalize_benchmark(value(attrs, :benchmark)) do
      {:ok,
       %{
         source_digest: source_digest,
         source_url: Map.get(observation, :source_url),
         response_mode: response_mode,
         target_repository: target_repository,
         required_capability: required_capability,
         benchmark: benchmark,
         standing: :candidate,
         authority: :select_only
       }}
    end
  end

  def qualify_opportunity(_observation, _attrs),
    do: refuse(:unadmitted_source_observation, %{})

  @doc """
  Intersects working-backwards claims with ALIVE evidence.

  Claims without a matching evidence receipt are withheld rather than silently
  promoted or treated as failures of the entire release. The result contains
  only evidence-backed earned claims plus the ids that remain unearned.
  """
  @spec qualify_release([map()], [map()]) :: result(map())
  def qualify_release(working_claims, evidence_receipts)
      when is_list(working_claims) and is_list(evidence_receipts) do
    with {:ok, claims} <- normalize_working_claims(working_claims),
         {:ok, evidence} <- normalize_evidence(evidence_receipts) do
      evidence_by_claim = Map.new(evidence, &{&1.claim_id, &1})

      {earned, withheld} =
        Enum.reduce(claims, {[], []}, fn claim, {earned, withheld} ->
          case Map.get(evidence_by_claim, claim.id) do
            %{standing: :alive} = receipt ->
              {[Map.put(claim, :evidence, receipt) | earned], withheld}

            _ ->
              {earned, [claim.id | withheld]}
          end
        end)

      earned = Enum.reverse(earned)
      withheld = Enum.reverse(withheld)

      {:ok,
       %{
         earned_claims: earned,
         withheld_claim_ids: withheld,
         standing: if(earned == [], do: :blocked, else: :alive),
         publication_authority: :none
       }}
    end
  end

  def qualify_release(_working_claims, _evidence_receipts),
    do: refuse(:invalid_release_inputs, %{})

  @doc "Checks that an observed lifecycle trace never moves backward in the factory stage order."
  @spec conform_trace([atom() | String.t()]) :: result(:conformant)
  def conform_trace(stages) when is_list(stages) do
    with {:ok, normalized} <- normalize_stages(stages),
         true <- nondecreasing?(normalized) do
      {:ok, :conformant}
    else
      false -> refuse(:stage_regression, %{stages: stages})
      {:error, _} = error -> error
    end
  end

  def conform_trace(value), do: refuse(:invalid_trace, %{got: inspect(value)})

  defp normalize_response_mode(mode) when mode in @response_modes, do: {:ok, mode}

  defp normalize_response_mode(mode) when is_binary(mode) do
    try do
      atom = String.to_existing_atom(mode)
      normalize_response_mode(atom)
    rescue
      ArgumentError -> refuse(:unknown_response_mode, %{response_mode: mode})
    end
  end

  defp normalize_response_mode(mode),
    do: refuse(:unknown_response_mode, %{response_mode: inspect(mode)})

  defp normalize_benchmark(%{} = benchmark) do
    with {:ok, id} <- required_string(benchmark, :id),
         {:ok, metric} <- required_string(benchmark, :metric),
         {:ok, acceptance} <- required_string(benchmark, :acceptance_predicate),
         {:ok, falsifier} <- required_string(benchmark, :falsifier) do
      {:ok,
       %{
         id: id,
         metric: metric,
         acceptance_predicate: acceptance,
         falsifier: falsifier
       }}
    end
  end

  defp normalize_benchmark(value),
    do: refuse(:invalid_benchmark, %{got: inspect(value)})

  defp normalize_claims(claims) when is_list(claims) do
    if Enum.all?(claims, &is_binary/1) do
      {:ok, Enum.reject(claims, &(&1 == ""))}
    else
      refuse(:invalid_observed_claims, %{claims: claims})
    end
  end

  defp normalize_claims(value),
    do: refuse(:invalid_observed_claims, %{got: inspect(value)})

  defp normalize_working_claims(claims) do
    Enum.reduce_while(claims, {:ok, []}, fn claim, {:ok, acc} ->
      with %{} <- claim,
           {:ok, id} <- required_string(claim, :id),
           {:ok, text} <- required_string(claim, :text) do
        {:cont, {:ok, [%{id: id, text: text} | acc]}}
      else
        _ -> {:halt, refuse(:invalid_working_claim, %{claim: inspect(claim)})}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      other -> other
    end
  end

  defp normalize_evidence(receipts) do
    Enum.reduce_while(receipts, {:ok, []}, fn receipt, {:ok, acc} ->
      case normalize_receipt(receipt) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      other -> other
    end
  end

  defp normalize_receipt(%{} = receipt) do
    with {:ok, claim_id} <- required_string(receipt, :claim_id),
         {:ok, subject_identity} <- required_string(receipt, :subject_identity),
         {:ok, verifier_identity} <- required_string(receipt, :verifier_identity),
         {:ok, evidence_ref} <- required_string(receipt, :evidence_ref),
         {:ok, replay_ref} <- required_string(receipt, :replay_ref),
         {:ok, standing} <- normalize_standing(value(receipt, :standing)) do
      {:ok,
       %{
         claim_id: claim_id,
         subject_identity: subject_identity,
         verifier_identity: verifier_identity,
         evidence_ref: evidence_ref,
         replay_ref: replay_ref,
         standing: standing
       }}
    end
  end

  defp normalize_receipt(value),
    do: refuse(:invalid_evidence_receipt, %{got: inspect(value)})

  defp normalize_standing(:alive), do: {:ok, :alive}
  defp normalize_standing("ALIVE"), do: {:ok, :alive}
  defp normalize_standing("alive"), do: {:ok, :alive}
  defp normalize_standing(value), do: {:ok, {:not_alive, value}}

  defp normalize_datetime(%DateTime{} = datetime), do: {:ok, datetime}

  defp normalize_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, reason} -> refuse(:invalid_published_at, %{reason: reason, value: value})
    end
  end

  defp normalize_datetime(value),
    do: refuse(:invalid_published_at, %{value: inspect(value)})

  defp normalize_stages(stages) do
    Enum.reduce_while(stages, {:ok, []}, fn stage, {:ok, acc} ->
      case normalize_stage(stage) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      other -> other
    end
  end

  defp normalize_stage(stage) when stage in @stages, do: {:ok, stage}

  defp normalize_stage(stage) when is_binary(stage) do
    case Enum.find(@stages, &(Atom.to_string(&1) == stage)) do
      nil -> refuse(:unknown_stage, %{stage: stage})
      atom -> {:ok, atom}
    end
  end

  defp normalize_stage(stage), do: refuse(:unknown_stage, %{stage: inspect(stage)})

  defp nondecreasing?(stages) do
    stages
    |> Enum.map(&Map.fetch!(@stage_index, &1))
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [left, right] -> left <= right end)
  end

  defp required_string(map, key) do
    case value(map, key) do
      string when is_binary(string) and byte_size(string) > 0 -> {:ok, string}
      got -> refuse(:missing_or_invalid_field, %{field: key, got: inspect(got)})
    end
  end

  defp value(map, key, default \\ nil) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp refuse(code, details), do: {:error, {:refused, code, details}}
end
