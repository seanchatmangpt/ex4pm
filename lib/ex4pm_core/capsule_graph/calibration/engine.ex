defmodule Ex4pmCore.CapsuleGraph.Calibration.Engine do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.Calibration.{
    Admission,
    Contribution,
    Decision,
    Receipt,
    Standing,
    Strategy
  }

  @spec qualify(map()) :: {:ok, map()} | {:error, term()}
  def qualify(%{models: models, witnesses: witnesses, now: now} = input)
      when is_map(models) and is_list(witnesses) do
    min_trials = Map.get(input, :min_trials, 4)
    required_clusters = Map.get(input, :required_clusters, 2)
    independent_clusters = Map.get(input, :independent_clusters, 0)
    strategy = Map.get(input, :strategy, :calibrated_log_odds)
    accept_threshold = Map.get(input, :accept_threshold, 1.0)
    reject_threshold = Map.get(input, :reject_threshold, -1.0)

    with {:ok, contributions, supports, outcomes} <-
           contributions(models, witnesses, now, min_trials),
         {:ok, strategy_value} <- Strategy.evaluate(strategy, contributions, supports),
         {:ok, decision} <- Decision.decide([strategy_value], accept_threshold, reject_threshold) do
      standing =
        Standing.derive(decision.result, outcomes, independent_clusters, required_clusters)

      receipt =
        Receipt.new(%{
          standing: standing,
          strategy: strategy,
          statistic: decision.statistic,
          witness_count: length(witnesses)
        })

      {:ok,
       %{
         standing: standing,
         decision: decision.result,
         strategy: strategy,
         statistic: decision.statistic,
         receipt: receipt,
         actuation_performed: false
       }}
    end
  end

  def qualify(_), do: {:error, {:refused, :invalid_calibration_qualification}}

  defp contributions(models, witnesses, now, min_trials) do
    Enum.reduce_while(witnesses, {:ok, [], [], []}, fn witness,
                                                       {:ok, values, supports, outcomes} ->
      case Map.fetch(models, witness.source_fingerprint) do
        :error ->
          {:halt, {:error, {:refused, :missing_calibration_model}}}

        {:ok, model} ->
          with :ok <- Admission.admit(model, witness, now, min_trials),
               {:ok, contribution} <- Contribution.from(model, witness.outcome) do
            {:cont,
             {:ok, [contribution.log_likelihood | values], [model.support | supports],
              [witness.outcome | outcomes]}}
          else
            error -> {:halt, error}
          end
      end
    end)
  end
end
