defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Authority do
  @moduledoc false

  @allowed [:observe, :select, :construct, :verify]

  def admit(action) when action in @allowed, do: {:ok, action}
  def admit(:do), do: {:error, {:refused, :brce_required_for_do}}
  def admit(action), do: {:error, {:refused, :unknown_authority_action, action}}
end
