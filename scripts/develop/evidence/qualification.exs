defmodule Ex4pm.Develop.Evidence.Qualification do
  def qualify(%{quorum: quorum, lease: lease, standing: standings}, now) do
    with {:ok, effective} <- Ex4pm.Develop.Evidence.EffectiveQuorum.admit(quorum.n, quorum.rho, quorum.minimum),
         :ok <- Ex4pm.Develop.Evidence.LeaseCurrentness.admit(lease, now) do
      %{standing: Ex4pm.Develop.Evidence.FailureDominance.standing(standings), effective_quorum: effective, authority: :verify, actuation: false}
    end
  end
end
