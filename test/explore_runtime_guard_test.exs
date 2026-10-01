defmodule Ex4pm.Explore.RuntimeGuardTest do
  use ExUnit.Case, async: true

  test "token bucket returns typed refusal without actuation" do
    assert {:refused, :insufficient_tokens, 1} = Ex4pm.Explore.TokenBucket.consume(1, 2)
    assert {:ok, 1} = Ex4pm.Explore.TokenBucket.consume(3, 2)
  end

  test "circuit breaker opens at threshold and closes after successful probe" do
    assert {:open, 3} = Ex4pm.Explore.CircuitBreaker.transition(:closed, {:failure, 2}, 3)
    assert {:half_open, 0} = Ex4pm.Explore.CircuitBreaker.transition(:open, :probe, 3)
    assert {:closed, 0} = Ex4pm.Explore.CircuitBreaker.transition(:half_open, :success, 3)
  end
end
