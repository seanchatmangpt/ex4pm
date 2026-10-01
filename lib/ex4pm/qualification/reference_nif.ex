defmodule Ex4pm.Qualification.ReferenceNif do
  @moduledoc false

  def load_nif do
    case System.fetch_env("EX4PM_REFERENCE_NIF") do
      {:ok, path} -> :erlang.load_nif(String.to_charlist(path), 0)
      :error -> {:error, :reference_nif_path_not_admitted}
    end
  end

  def qualification_probe(_value, _opts), do: :erlang.nif_error(:nif_not_loaded)
  def panic_probe(), do: :erlang.nif_error(:nif_not_loaded)
end
