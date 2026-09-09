defmodule Ex4pmCore.CapsuleGraph.Pipeline do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.{Authority, Receipt, Replay, Selector}

  def construct(candidates, required_capabilities, input, output) do
    with {:ok, :select} <- Authority.admit(:select),
         {:ok, selected, alternatives} <- Selector.select(candidates, required_capabilities),
         {:ok, :construct} <- Authority.admit(:construct) do
      receipt = Receipt.new(selected, input, output)

      with {:ok, :match} <- Replay.verify(receipt) do
        {:ok,
         %{
           selected: selected,
           alternatives: alternatives,
           output: output,
           receipt: receipt,
           actuation_performed: false
         }}
      end
    end
  end
end
