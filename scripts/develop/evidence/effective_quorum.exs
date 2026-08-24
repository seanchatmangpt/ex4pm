defmodule Ex4pm.Develop.Evidence.EffectiveQuorum do
  def effective(n, rho) when n > 0 and rho >= 0 and rho < 1, do: n / (1 + (n - 1) * rho)
  def admit(n, rho, minimum) do
    value=effective(n,rho)
    if value >= minimum, do: {:ok,value}, else: {:refused,{:pseudo_quorum,value}}
  end
end
