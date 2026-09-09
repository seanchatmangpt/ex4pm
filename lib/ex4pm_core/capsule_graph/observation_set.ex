defmodule Ex4pmCore.CapsuleGraph.ObservationSet do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.{Evidence, Subject}

  @enforce_keys [:subject, :observations]
  defstruct [:subject, :observations]

  def new(%Subject{} = subject, observations) when is_list(observations) do
    if Enum.all?(observations, fn
         %Evidence{subject: observed} -> Subject.same?(subject, observed)
         _ -> false
       end) do
      {:ok, %__MODULE__{subject: subject, observations: observations}}
    else
      {:error, {:refused, :mixed_subject_observation_set}}
    end
  end

  def new(_, _), do: {:error, {:refused, :invalid_observation_set}}
end
