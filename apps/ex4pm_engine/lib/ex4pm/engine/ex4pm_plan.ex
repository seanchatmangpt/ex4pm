defmodule Ex4pm.Engine.Ex4pmPlan do
  @moduledoc """
  Adapter for the pinned ex4pm-plan cloud worker protocol.

  This is an analytical CONSTRUCT edge. Provider authority remains outside the
  adapter. ALIVE requires the exact pinned worker source, OCI digest and worker
  replay evidence.
  """

  @behaviour Ex4pm.Engine
  alias Ex4pm.Engine.Result
  alias Ex4pm.Refusal

  @protocol "ex4pm-plan/v1"
  @source_sha "99816fb389670174be44ddaaf3b42f00496e6f21"

  @impl true
  def id, do: :ex4pm_plan
  @impl true
  def supports?(:plan, opts), do: Keyword.get(opts, :planner, :astar) in [:astar, "astar"]
  def supports?(_operation, _opts), do: false
  @impl true
  def available?(opts), do: supports?(:plan, opts) and is_function(Keyword.get(opts, :ex4pm_plan_fun), 2)

  @impl true
  def execute(:plan, subject, opts) when is_map(subject) do
    case Keyword.get(opts, :ex4pm_plan_fun) do
      fun when is_function(fun, 2) ->
        request = %{"solver" => "astar", "problem" => json_term(subject)}
        case fun.(request, opts) do
          {:ok, response, identity} when is_map(response) -> accept(response, identity, subject)
          {:ok, response} when is_map(response) -> accept(response, nil, subject)
          response when is_map(response) -> accept(response, nil, subject)
          {:error, %Refusal{} = refusal} -> {:error, refusal}
          {:error, reason} -> {:error, Refusal.new(:ex4pm_plan_transport_failed, "ex4pm-plan transport failed", details: %{reason: inspect(reason)})}
          other -> {:error, Refusal.new(:invalid_ex4pm_plan_transport_result, "ex4pm-plan transport returned an invalid value", details: %{result: inspect(other)})}
        end
      _ -> {:error, Refusal.new(:ex4pm_plan_unavailable, "ex4pm-plan requires an explicit transport callback")}
    end
  end

  def execute(:plan, subject, _opts), do: {:error, Refusal.new(:invalid_planning_problem, "ex4pm-plan requires a map planning problem", subject: subject)}
  def execute(operation, subject, _opts), do: {:error, Refusal.new(:unsupported_ex4pm_plan_operation, "ex4pm-plan only supports planning", subject: subject, details: %{operation: operation})}
  def protocol, do: @protocol
  def source_sha, do: @source_sha

  defp accept(response, identity, subject) do
    case field(response, :standing) do
      "REFUSED" -> {:error, Refusal.new(:planner_refused, "ex4pm-plan refused the planning problem", subject: subject, details: %{remote_refusal: field(response, :refusal)})}
      "UNSUPPORTED" -> {:error, Refusal.new(:planner_unsupported, "ex4pm-plan does not support the requested planning edge", subject: subject, details: %{remote_reason: field(response, :reason)})}
      _ -> accept_success(response, identity, subject)
    end
  end

  defp accept_success(response, identity, subject) do
    evidence = field(response, :evidence)
    result = field(response, :result)
    with true <- field(response, :protocol) == @protocol,
         true <- field(response, :status) == "ok",
         true <- field(response, :standing) == "ALIVE",
         true <- is_map(evidence),
         true <- field(evidence, :replay_verified) == true,
         worker_subject_hash when is_binary(worker_subject_hash) <- field(evidence, :subject_hash),
         worker_result_hash when is_binary(worker_result_hash) <- field(evidence, :result_hash),
         true <- is_map(result),
         :ok <- validate_observed_identity(identity) do
      observed? = exact_observed_identity?(identity)
      {:ok, %Result{engine: :ex4pm_plan, operation: :plan, algorithm: :astar, subject_hash: Ex4pm.Core.Hash.digest(subject), standing: if(observed?, do: :alive, else: :partial_alive), value: result, evidence: %{protocol: @protocol, worker_source_sha: @source_sha, worker_subject_hash: worker_subject_hash, worker_result_hash: worker_result_hash, replay_verified: true, transport_identity: identity, identity_observed: observed?, executed: true}}}
    else
      {:error, %Refusal{} = refusal} -> {:error, refusal}
      _ -> {:error, Refusal.new(:invalid_ex4pm_plan_response, "ex4pm-plan response failed protocol admission", subject: subject, details: %{protocol: field(response, :protocol), standing: field(response, :standing)})}
    end
  end

  defp validate_observed_identity(identity) do
    if observed_identity?(identity) and field(identity, :source_sha) != @source_sha,
      do: {:error, Refusal.new(:ex4pm_plan_identity_mismatch, "observed planner source does not match the pinned fork head", details: %{expected: @source_sha, observed: field(identity, :source_sha)})},
      else: :ok
  end

  defp exact_observed_identity?(identity), do: observed_identity?(identity) and field(identity, :source_sha) == @source_sha and is_binary(field(identity, :image_digest)) and byte_size(field(identity, :image_digest)) > 0
  defp observed_identity?(identity), do: is_map(identity) and field(identity, :observed) == true
  defp field(map, key) when is_map(map), do: case(Map.fetch(map, key), do: ({:ok, value} -> value; :error -> Map.get(map, Atom.to_string(key))))
  defp field(_other, _key), do: nil
  defp json_term(value) when is_map(value), do: Map.new(value, fn {key, nested} -> {to_string(key), json_term(nested)} end)
  defp json_term(value) when is_list(value), do: Enum.map(value, &json_term/1)
  defp json_term(value) when value in [true, false, nil], do: value
  defp json_term(value) when is_atom(value), do: Atom.to_string(value)
  defp json_term(value), do: value
end
