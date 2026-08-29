defmodule Ex4pm.Explore.LamportClock do
  @moduledoc false
  def tick(clock), do: clock + 1
  def receive(local, remote), do: max(local, remote) + 1
end
