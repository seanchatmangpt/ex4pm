defmodule Ex4pm.Explore.TokenBucket do
  @moduledoc false
  def refill(tokens, capacity, elapsed_ms, rate_per_sec) do
    min(capacity, tokens + elapsed_ms * rate_per_sec / 1000.0)
  end
  def consume(tokens, cost) when cost >= 0 do
    if tokens >= cost, do: {:ok, tokens - cost}, else: {:refused, :insufficient_tokens, tokens}
  end
end
