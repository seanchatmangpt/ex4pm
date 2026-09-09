defmodule Ex4pmCore.CapsuleGraph.Authority do
  @moduledoc false

  @non_consequential [:observe, :select, :construct, :verify]

  def admit(action) when action in @non_consequential, do: {:ok, action}
  def admit(:do), do: {:error, {:refused, :brce_required_for_do}}
  def admit(action), do: {:error, {:refused, :unknown_capsule_action, action}}

  def non_consequential, do: @non_consequential
end
