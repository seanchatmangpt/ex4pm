defmodule Ex4pmCore.CapsuleGraph.Currentness.Engine do
  @moduledoc false
  alias Ex4pmCore.CapsuleGraph.Currentness.{ABA, Admission, Receipt}

  def qualify(attempt, contexts, witness, now) when is_list(contexts) and contexts != [] do
    with :ok <- ABA.detect(contexts),
         current <- List.last(contexts),
         {:ok, admission} <- Admission.admit(attempt, current, witness, now) do
      receipt = Receipt.issue(admission)
      {:ok, %{admission: admission, receipt: receipt, replay: Receipt.replay(receipt), actuation_performed: false}}
    end
  end

  def qualify(_, _, _, _), do: {:error, {:refused, :empty_context_history}}
end
