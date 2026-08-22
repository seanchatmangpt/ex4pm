defmodule Ex4pm.Run do
  @moduledoc "Public evidence envelope for an analytical ex4pm operation."
  @enforce_keys [:operation, :subject_hash, :standing, :value, :receipt]
  defstruct [
    :operation,
    :subject_hash,
    :standing,
    :value,
    :receipt,
    :pending,
    :engine_result,
    projections: []
  ]
end

defmodule Ex4pm do
  @moduledoc "Public orchestration API for BEAM-native process intelligence."

  alias Ex4pm.Domain.Projector
  alias Ex4pm.Engine
  alias Ex4pm.Engine.Differential
  alias Ex4pm.Evidence.{Receipt, Store}
  alias Ex4pm.Evidence.Replay.Chain
  alias Ex4pm.{EventLog, OCEL, POWL, Refusal, Run, XES}

  def contracts, do: Ex4pm.Contracts.verify()

  def ingest(raw, opts \\ []) do
    with {:ok, log} <- OCEL.normalize(raw),
         {:ok, projections} <- maybe_project_dataset(log, opts) do
      {:ok, %{log | metadata: Map.put(log.metadata, :projections, projections)}}
    end
  end

  def ingest_xes(xml, opts \\ []) do
    with {:ok, log} <- XES.parse(xml, opts),
         {:ok, projections} <- maybe_project_dataset(log, opts) do
      {:ok, %{log | metadata: Map.put(log.metadata, :projections, projections)}}
    end
  end

  def discover(subject, opts \\ []) do
    with {:ok, log} <- ensure_log(subject),
         {:ok, engine_result} <- Engine.execute(:discover, log, opts) do
      receipted_run(:discover, log.subject.hash, engine_result, opts)
    end
  end

  def conform(subject, model, opts \\ []) do
    with {:ok, log} <- ensure_log(subject),
         {:ok, engine_result} <- Engine.execute(:conform, {log, model}, opts) do
      receipted_run(:conform, log.subject.hash, engine_result, opts)
    end
  end

  def simulate(model, opts \\ []) do
    with {:ok, engine_result} <- Engine.execute(:simulate, model, opts) do
      receipted_run(:simulate, Ex4pm.Core.Hash.digest(model), engine_result, opts)
    end
  end

  def optimize(subject, model, opts \\ []) do
    with {:ok, log} <- ensure_log(subject),
         {:ok, engine_result} <- Engine.execute(:optimize, {log, model}, opts) do
      receipted_run(:optimize, log.subject.hash, engine_result, opts)
    end
  end

  def plan(problem, opts \\ [])

  def plan(problem, opts) when is_map(problem) do
    opts = Keyword.put_new(opts, :engine, :ex4pm_plan)

    with {:ok, engine_result} <- Engine.execute(:plan, problem, opts) do
      receipted_run(:plan, Ex4pm.Core.Hash.digest(problem), engine_result, opts)
    end
  end

  def plan(other, _opts) do
    {:error,
     Refusal.new(:invalid_planning_problem, "plan requires an admitted planning problem map",
       subject: other
     )}
  end

  def operate(subject, authority, opts \\ [])

  def operate(%POWL{} = model, authority, opts) do
    with {:ok, plan} <- Ex4pm.Runtime.compile(model),
         {:ok, execution} <- Ex4pm.Runtime.execute(plan, authority, opts) do
      {:ok, %{plan: plan, execution: execution, standing: execution.standing}}
    end
  end

  def operate(%Ex4pm.Runtime.Plan{} = plan, authority, opts) do
    with {:ok, execution} <- Ex4pm.Runtime.execute(plan, authority, opts) do
      {:ok, %{plan: plan, execution: execution, standing: execution.standing}}
    end
  end

  def operate(other, _authority, _opts) do
    {:error,
     Refusal.new(:invalid_operable_subject, "operate requires POWL or a compiled runtime plan",
       subject: other
     )}
  end

  def stream(events, opts) when is_list(opts) do
    Ex4pm.Stream.Pipeline.start_link(Keyword.put(opts, :events, events))
  end

  def capabilities(operation \\ :discover, opts \\ []), do: Engine.candidates(operation, opts)

  def differential(operation, subject, left_engine, right_engine, opts \\ []) do
    Differential.compare(operation, subject, left_engine, right_engine, opts)
  end

  def replay(hash, opts \\ []) when is_binary(hash) do
    store = Keyword.get(opts, :store, Store)

    case Store.get(hash, store) do
      {:ok, receipt} ->
        Chain.verify(receipt, store)

      :error ->
        {:error,
         Refusal.new(:receipt_not_found, "receipt hash is not present in runtime ledger",
           details: %{hash: hash}
         )}
    end
  end

  defp receipted_run(operation, subject_hash, engine_result, opts) do
    store = Keyword.get(opts, :store, Store)

    pending =
      Receipt.pending(subject_hash, {:analysis, operation}, nil, %{
        engine: engine_result.engine,
        algorithm: engine_result.algorithm,
        engine_evidence: engine_result.evidence
      })

    with {:ok, _} <- Store.put(pending, store) do
      outcome =
        Receipt.outcome(pending, engine_result.value, engine_result.standing, %{
          engine: engine_result.engine,
          algorithm: engine_result.algorithm,
          engine_evidence: engine_result.evidence
        })

      with {:ok, _} <- Store.put(outcome, store),
           {:ok, projections} <- maybe_project_run(operation, engine_result, outcome, opts) do
        {:ok,
         %Run{
           operation: operation,
           subject_hash: subject_hash,
           standing: engine_result.standing,
           value: engine_result.value,
           receipt: outcome,
           pending: pending,
           engine_result: engine_result,
           projections: projections
         }}
      end
    end
  end

  defp maybe_project_dataset(log, opts) do
    if Keyword.get(opts, :project?, false) do
      case Projector.dataset(log) do
        {:ok, projection} -> {:ok, [projection]}
        error -> error
      end
    else
      {:ok, []}
    end
  end

  defp maybe_project_run(operation, engine_result, receipt, opts) do
    if Keyword.get(opts, :project?, false) do
      with {:ok, receipt_projection} <- Projector.receipt(receipt) do
        case operation do
          :discover ->
            with {:ok, model_projection} <- Projector.process_model(engine_result) do
              {:ok, [model_projection, receipt_projection]}
            end

          :optimize ->
            candidates = Map.get(engine_result.value, :candidates, [])

            candidates
            |> Enum.reduce_while({:ok, [receipt_projection]}, fn candidate, {:ok, acc} ->
              case Projector.intervention(engine_result.subject_hash, candidate) do
                {:ok, projection} -> {:cont, {:ok, [projection | acc]}}
                error -> {:halt, error}
              end
            end)
            |> case do
              {:ok, projections} -> {:ok, Enum.reverse(projections)}
              error -> error
            end

          _ ->
            {:ok, [receipt_projection]}
        end
      end
    else
      {:ok, []}
    end
  end

  defp ensure_log(%EventLog{} = log), do: {:ok, log}
  defp ensure_log(raw), do: OCEL.normalize(raw)
end
