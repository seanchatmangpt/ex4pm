defmodule Ex4pmCore.CapsuleGraph.Currentness.Lease do
  @moduledoc false
  @enforce_keys [:not_before, :expires_at]
  defstruct [:not_before, :expires_at]

  def new(not_before, expires_at)
      when is_integer(not_before) and is_integer(expires_at) and not_before < expires_at,
      do: {:ok, %__MODULE__{not_before: not_before, expires_at: expires_at}}

  def new(_, _), do: {:error, {:refused, :invalid_lease}}

  def active?(%__MODULE__{not_before: start_at, expires_at: end_at}, now) when is_integer(now),
    do: start_at <= now and now < end_at
end
