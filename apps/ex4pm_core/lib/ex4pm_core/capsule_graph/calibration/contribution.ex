defmodule Ex4pmCore.CapsuleGraph.Calibration.Contribution do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.Calibration.Model

  @enforce_keys [:outcome, :log_likelihood]
  defstruct [:outcome, :log_likelihood]

  @spec from(Model.t() | struct(), atom()) :: {:ok, struct()} | {:error, term()}
  def from(%Model{} = model, outcome) when outcome in [:pass, :fail, :pending, :unknown, :unsupported] do
    value =
      case outcome do
        :pass -> :math.log(model.tpr / model.fpr)
        :fail -> :math.log((1.0 - model.tpr) / (1.0 - model.fpr))
        _ -> 0.0
      end

    {:ok, %__MODULE__{outcome: outcome, log_likelihood: value}}
  end

  def from(_, _), do: {:error, {:refused, :invalid_calibration_contribution}}
end
