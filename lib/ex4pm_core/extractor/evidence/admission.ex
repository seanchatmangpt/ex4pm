defmodule Ex4pmCore.ProcessIR.Extractor.Evidence.Admission do
  @moduledoc false

  def admit(%{standing: :partial_alive} = candidate), do: {:ok, candidate}
  def admit(%{standing: :alive} = candidate), do: {:ok, candidate}

  def admit(%{standing: :unsupported, name: name}),
    do: {:error, {:unsupported, :extractor_unavailable, name}}

  def admit(%{name: name, standing: standing}),
    do: {:error, {:refused, :extractor_not_admitted, {name, standing}}}

  def admit(other), do: {:error, {:refused, :invalid_candidate, other}}
end
