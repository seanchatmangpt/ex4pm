defmodule Ex4pmCore.CapsuleGraph.Calibration.Admission do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.Calibration.{Model, Witness}

  @spec admit(Model.t() | struct(), Witness.t() | struct(), DateTime.t(), pos_integer()) :: :ok | {:error, term()}
  def admit(%Model{} = model, %Witness{} = witness, %DateTime{} = now, min_trials)
      when is_integer(min_trials) and min_trials > 0 do
    cond do
      model.source_id != witness.source_fingerprint -> {:error, {:refused, :source_calibration_mismatch}}
      DateTime.compare(witness.observed_at, now) == :gt -> {:error, {:refused, :future_evidence}}
      model.support < min_trials -> {:error, {:refused, :insufficient_calibration_support}}
      true -> :ok
    end
  end

  def admit(_, _, _, _), do: {:error, {:refused, :invalid_calibration_admission}}
end
