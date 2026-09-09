defmodule Ex4pm.Qualification.ReferenceNif do
  @moduledoc false
  @on_load :load_nif

  def load_nif do
    case System.get_env("EX4PM_REFERENCE_NIF") do
      nil -> :ok
      path -> :erlang.load_nif(String.to_charlist(path), 0)
    end
  end

  def qualification_probe(_value, _opts), do: :erlang.nif_error(:nif_not_loaded)
  def panic_probe(), do: :erlang.nif_error(:nif_not_loaded)
end
