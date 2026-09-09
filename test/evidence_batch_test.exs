defmodule Ex4pm.Evidence.BatchTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Evidence.Batch
  alias Ex4pm.Standing.Coded

  test "new/2 starts at zero counters with no standing set yet" do
    batch = Batch.new("batch-1", 50)

    assert batch.id == "batch-1"
    assert batch.target == 50
    assert batch.admitted == 0
    assert batch.qualified == 0
    assert batch.published == 0
    assert batch.merged == 0
    assert batch.next_cell == nil
    assert batch.standing == nil
  end

  test "advance/2 correctly bumps each counter independently" do
    batch = Batch.new("batch-1", 50)

    admitted_only = Batch.advance(batch, %{admitted: 3})
    assert admitted_only.admitted == 3
    assert admitted_only.qualified == 0
    assert admitted_only.published == 0
    assert admitted_only.merged == 0

    qualified_only = Batch.advance(batch, %{qualified: 5})
    assert qualified_only.qualified == 5
    assert qualified_only.admitted == 0

    published_only = Batch.advance(batch, %{published: 2})
    assert published_only.published == 2
    assert published_only.admitted == 0

    merged_only = Batch.advance(batch, %{merged: 1})
    assert merged_only.merged == 1
    assert merged_only.admitted == 0

    combined =
      batch
      |> Batch.advance(%{admitted: 3, qualified: 2})
      |> Batch.advance(%{qualified: 1, published: 1, next_cell: "cell-7"})

    assert combined.admitted == 3
    assert combined.qualified == 3
    assert combined.published == 1
    assert combined.merged == 0
    assert combined.next_cell == "cell-7"
  end

  test "resume/1 on a fresh/open batch returns {:continue, batch}" do
    batch = Batch.new("batch-1", 50)

    assert {:continue, ^batch} = Batch.resume(batch)
  end

  test "resume/1 on a batch whose standing is already closed returns {:prohibited, reason}, never silently re-opens" do
    alive_batch = %{Batch.new("batch-1", 50) | standing: Coded.new(:alive, "batch-1_50")}
    assert {:prohibited, reason} = Batch.resume(alive_batch)
    assert reason =~ "prohibited"
    assert reason =~ "batch-1"

    build_broken_batch = %{
      Batch.new("batch-2", 50)
      | standing: Coded.new(:build_broken, "TAKT_SHORTFALL")
    }

    assert {:prohibited, reason2} = Batch.resume(build_broken_batch)
    assert reason2 =~ "prohibited"
    assert reason2 =~ "batch-2"

    # a non-closed standing (e.g. partial_alive) must still be continuable
    partial_batch = %{Batch.new("batch-3", 50) | standing: Coded.new(:partial_alive)}
    assert {:continue, ^partial_batch} = Batch.resume(partial_batch)
  end

  test "quota_met?/1 true/false cases" do
    under = Batch.new("batch-1", 50) |> Batch.advance(%{qualified: 49})
    refute Batch.quota_met?(under)

    exact = Batch.new("batch-1", 50) |> Batch.advance(%{qualified: 50})
    assert Batch.quota_met?(exact)

    over = Batch.new("batch-1", 50) |> Batch.advance(%{qualified: 51})
    assert Batch.quota_met?(over)
  end

  test "close/1 produces the real ALIVE[<id>_50]-shaped coded standing when quota met" do
    batch = Batch.new("batch-1", 50) |> Batch.advance(%{qualified: 50})
    closed = Batch.close(batch)

    assert closed.standing == Coded.new(:alive, "batch-1_50")
    assert Coded.to_string(closed.standing) == "ALIVE[batch-1_50]"
  end

  test "close/1 produces BUILD_BROKEN[TAKT_SHORTFALL] when quota not met" do
    batch = Batch.new("batch-1", 50) |> Batch.advance(%{qualified: 10})
    closed = Batch.close(batch)

    assert closed.standing == Coded.new(:build_broken, "TAKT_SHORTFALL")
    assert Coded.to_string(closed.standing) == "BUILD_BROKEN[TAKT_SHORTFALL]"
  end
end
