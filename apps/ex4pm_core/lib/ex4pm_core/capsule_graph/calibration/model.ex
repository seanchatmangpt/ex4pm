defmodule Ex4pmCore.CapsuleGraph.Calibration.Model do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.Calibration.Trial

  @enforce_keys [:source_id, :support, :tp, :tn, :fp, :fn, :tpr, :fpr, :brier]
  defstruct [:source_id, :support, :tp, :tn, :fp, :fn, :tpr, :fpr, :brier]

  @type t :: %__MODULE__{
          source_id: String.t(),
          support: non_neg_integer(),
          tp: non_neg_integer(),
          tn: non_neg_integer(),
          fp: non_neg_integer(),
          fn: non_neg_integer(),
          tpr: float(),
          fpr: float(),
          brier: float()
        }

  @spec fit([Trial.t()]) :: {:ok, t()} | {:error, term()}
  def fit([]), do: {:error, {:refused, :empty_calibration_history}}

  def fit(trials) when is_list(trials) do
    source_ids = trials |> Enum.map(& &1.source_id) |> Enum.uniq()
    ids = Enum.map(trials, & &1.id)

    cond do
      length(source_ids) != 1 -> {:error, {:refused, :mixed_calibration_sources}}
      length(ids) != length(Enum.uniq(ids)) -> {:error, {:refused, :duplicate_calibration_trial}}
      true -> build(hd(source_ids), trials)
    end
  end

  defp build(source_id, trials) do
    tp = Enum.count(trials, &(&1.truth == :pass and &1.prediction == :pass))
    tn = Enum.count(trials, &(&1.truth == :fail and &1.prediction == :fail))
    fp = Enum.count(trials, &(&1.truth == :fail and &1.prediction == :pass))
    fnn = Enum.count(trials, &(&1.truth == :pass and &1.prediction == :fail))
    support = length(trials)
    tpr = (tp + 1) / (tp + fnn + 2)
    fpr = (fp + 1) / (fp + tn + 2)
    brier = Enum.reduce(trials, 0.0, fn acc, t -> acc + brier_term(t) end) / support
    {:ok, %__MODULE__{source_id: source_id, support: support, tp: tp, tn: tn, fp: fp, fn: fnn, tpr: tpr, fpr: fpr, brier: brier}}
  end

  defp brier_term(%{truth: truth, prediction: prediction}) do
    y = if truth == :pass, do: 1.0, else: 0.0
    p = if prediction == :pass, do: 1.0, else: 0.0
    :math.pow(p - y, 2)
  end
end
