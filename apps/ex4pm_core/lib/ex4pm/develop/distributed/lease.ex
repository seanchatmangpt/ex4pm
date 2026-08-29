defmodule Ex4pm.Develop.Distributed.Lease do
  @moduledoc false
  defstruct [:holder, :generation, :starts_at, :expires_at]
  def valid?(%__MODULE__{generation: g, starts_at: s, expires_at: e}, now) when is_integer(g) and g >= 0, do: s <= now and now < e
  def valid?(_, _), do: false
end
