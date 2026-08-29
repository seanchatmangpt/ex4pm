defmodule Ex4pm.Runtime.PlanningPoolTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Runtime.PlanningPool

  test "acquiring within the bound grants the requested slots" do
    pool = PlanningPool.new(2)

    assert {:ok, 1} = PlanningPool.acquire(pool)
    assert {:ok, 1} = PlanningPool.acquire(pool)
    assert {:ok, available, 2} = PlanningPool.status(pool)
    assert available == 0
  end

  test "acquiring past the bound is refused (grants fewer slots than requested, per the real ConcurrencyTracker contract)" do
    pool = PlanningPool.new(1)

    assert {:ok, 1} = PlanningPool.acquire(pool)
    # pool is now exhausted: a further request for 1 slot grants 0
    assert {:ok, 0} = PlanningPool.acquire(pool)
    assert {:ok, 0, 1} = PlanningPool.status(pool)
  end

  test "requesting more than available grants only what remains" do
    pool = PlanningPool.new(3)

    assert {:ok, 1} = PlanningPool.acquire(pool)
    # 2 remain; requesting 5 grants only the 2 that are actually available
    assert {:ok, 2} = PlanningPool.acquire(pool, 5)
    assert {:ok, 0, 3} = PlanningPool.status(pool)
  end

  test "release returns slots to the pool for reuse" do
    pool = PlanningPool.new(1)

    assert {:ok, 1} = PlanningPool.acquire(pool)
    assert {:ok, 0} = PlanningPool.acquire(pool)

    assert :ok = PlanningPool.release(pool)
    assert {:ok, 1, 1} = PlanningPool.status(pool)

    assert {:ok, 1} = PlanningPool.acquire(pool)
  end

  test "releasing more than the limit allows is refused" do
    pool = PlanningPool.new(1)

    assert :error = PlanningPool.release(pool, 2)
  end

  test "release_on_exit returns the slot when the acquiring process terminates" do
    pool = PlanningPool.new(1)

    test_pid = self()

    {:ok, worker_pid} =
      Task.start(fn ->
        {:ok, 1} = PlanningPool.acquire(pool)
        PlanningPool.release_on_exit(pool)
        send(test_pid, :acquired)

        receive do
          :stop -> :ok
        end
      end)

    assert_receive :acquired
    assert {:ok, 0, 1} = PlanningPool.status(pool)

    ref = Process.monitor(worker_pid)
    send(worker_pid, :stop)
    assert_receive {:DOWN, ^ref, :process, ^worker_pid, _reason}

    # Give the ConcurrencyTracker's own monitor a moment to process the DOWN.
    assert eventually(fn -> PlanningPool.status(pool) == {:ok, 1, 1} end)
  end

  test "destroy tears down the pool" do
    pool = PlanningPool.new(1)
    assert :ok = PlanningPool.destroy(pool)
    assert {:error, _reason} = PlanningPool.status(pool)
  end

  defp eventually(fun, attempts \\ 20)
  defp eventually(_fun, 0), do: false

  defp eventually(fun, attempts) do
    if fun.() do
      true
    else
      Process.sleep(10)
      eventually(fun, attempts - 1)
    end
  end
end
