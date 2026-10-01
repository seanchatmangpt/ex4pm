defmodule Ex4pm.Develop.Distributed.EffectiveQuorum do
  @moduledoc false
  def effective(n, rho) when is_integer(n) and n > 0 and is_number(rho) and rho >= 0 and rho < 1, do: n / (1 + (n - 1) * rho)
  def effective(_, _), do: {:error, :invalid_correlation}
  def admit?(n, rho, threshold) do
    case effective(n, rho) do
      x when is_number(x) -> x >= threshold
      _ -> false
    end
  end
end
