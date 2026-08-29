defmodule Ex4pm.Runtime.PlanningPool do
  @moduledoc """
  A thin, real wrapper around `Reactor.Executor.ConcurrencyTracker` that
  bounds concurrent planning work.

  `Reactor.Executor.ConcurrencyTracker` is a `GenServer` already started by
  the vendored `:reactor` OTP application's supervision tree
  (`deps/reactor/lib/reactor/application.ex`), so this module does not start
  or own that process — it only allocates/uses pools against it.

  A pool is identified by an opaque `pool_key` (a `reference/0`, per the real
  `ConcurrencyTracker` API). `acquire/2` returns the number of slots actually
  granted (which may be less than requested, or zero, per the real
  `ConcurrencyTracker.acquire/2` contract) rather than blocking.
  """

  alias Reactor.Executor.ConcurrencyTracker

  @type pool_key :: ConcurrencyTracker.pool_key()

  @doc "Allocate a new bounded planning pool with `limit` concurrent slots."
  @spec new(pos_integer()) :: pool_key
  def new(limit) when is_integer(limit) and limit > 0 do
    ConcurrencyTracker.allocate_pool(limit)
  end

  @doc """
  Attempt to acquire `how_many` planning slots (default 1) from the pool.

  Returns `{:ok, n}` where `n` is the number of slots actually granted; `n`
  may be less than `how_many`, including `0`, if the pool is exhausted. The
  caller must only proceed with the work it was actually granted slots for.
  """
  @spec acquire(pool_key, pos_integer()) :: {:ok, non_neg_integer()}
  def acquire(pool_key, how_many \\ 1) do
    ConcurrencyTracker.acquire(pool_key, how_many)
  end

  @doc "Release `how_many` (default 1) previously acquired slots back to the pool."
  @spec release(pool_key, pos_integer()) :: :ok | :error
  def release(pool_key, how_many \\ 1) do
    ConcurrencyTracker.release(pool_key, how_many)
  end

  @doc "Release all acquired slots for the calling process automatically when it exits."
  @spec release_on_exit(pool_key, pid) :: :ok
  def release_on_exit(pool_key, pid \\ self()) do
    ConcurrencyTracker.release_on_exit(pool_key, pid)
  end

  @doc "Tear down the pool. Does not affect slots already acquired by users."
  @spec destroy(pool_key) :: :ok
  def destroy(pool_key), do: ConcurrencyTracker.release_pool(pool_key)

  @doc "Return `{:ok, available, limit}` for the pool, or `{:error, reason}`."
  @spec status(pool_key) :: {:ok, non_neg_integer(), pos_integer()} | {:error, any()}
  def status(pool_key), do: ConcurrencyTracker.status(pool_key)
end
