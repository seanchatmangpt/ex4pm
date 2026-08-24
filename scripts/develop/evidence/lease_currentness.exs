defmodule Ex4pm.Develop.Evidence.LeaseCurrentness do
  def current?(%{starts_at: start_at, expires_at: end_at}, now), do: start_at <= now and now < end_at
  def admit(lease, now), do: if(current?(lease,now),do: :ok,else: {:refused,:stale_evidence_lease})
end
