defmodule Ex4pmEngine.Beam.AllenTemporalTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Beam.AllenTemporal

  # Fixed literal OCEL-shaped event-pair fixtures (real DateTime values, hand
  # verified against Allen's interval algebra definitions).
  @t0 ~U[2026-01-01 00:00:00Z]
  @t1 ~U[2026-01-01 01:00:00Z]
  @t2 ~U[2026-01-01 02:00:00Z]
  @t3 ~U[2026-01-01 03:00:00Z]
  @t4 ~U[2026-01-01 04:00:00Z]

  test "disjoint intervals with a gap -> :before / :after" do
    # a: [t0, t1)   b: [t2, t3)  -- a ends strictly before b starts
    a = %{start: @t0, end: @t1}
    b = %{start: @t2, end: @t3}

    assert AllenTemporal.relation(a, b) == :before
    assert AllenTemporal.relation(b, a) == :after
  end

  test "touching intervals (a.end == b.start) -> :meets / :met_by" do
    # a: [t0, t1)   b: [t1, t2)  -- a's right endpoint touches b's left endpoint
    a = %{start: @t0, end: @t1}
    b = %{start: @t1, end: @t2}

    assert AllenTemporal.relation(a, b) == :meets
    assert AllenTemporal.relation(b, a) == :met_by
  end

  test "partially overlapping intervals -> :overlaps / :overlapped_by" do
    # a: [t0, t2)   b: [t1, t3)  -- a starts first, ends inside b, b ends last
    a = %{start: @t0, end: @t2}
    b = %{start: @t1, end: @t3}

    assert AllenTemporal.relation(a, b) == :overlaps
    assert AllenTemporal.relation(b, a) == :overlapped_by
  end

  test "identical intervals -> :equals" do
    a = %{start: @t0, end: @t2}
    b = %{start: @t0, end: @t2}

    assert AllenTemporal.relation(a, b) == :equals
    assert AllenTemporal.relation(b, a) == :equals
  end

  test "shared start, a shorter -> :starts / :started_by" do
    # a: [t0, t1)   b: [t0, t3) -- same start, a ends first (contained by b)
    a = %{start: @t0, end: @t1}
    b = %{start: @t0, end: @t3}

    assert AllenTemporal.relation(a, b) == :starts
    assert AllenTemporal.relation(b, a) == :started_by
  end

  test "shared end, a shorter -> :finishes / :finished_by" do
    # a: [t2, t3)   b: [t0, t3) -- same end, a starts later (contained by b)
    a = %{start: @t2, end: @t3}
    b = %{start: @t0, end: @t3}

    assert AllenTemporal.relation(a, b) == :finishes
    assert AllenTemporal.relation(b, a) == :finished_by
  end

  test "one interval strictly inside another -> :during / :contains" do
    # a: [t1, t2)   b: [t0, t4) -- a is strictly inside b on both endpoints
    a = %{start: @t1, end: @t2}
    b = %{start: @t0, end: @t4}

    assert AllenTemporal.relation(a, b) == :during
    assert AllenTemporal.relation(b, a) == :contains
  end

  test "interval_of/1 builds a real Interval.DateTimeInterval matching relation/2 on structs" do
    a = AllenTemporal.interval_of(%{start: @t0, end: @t1})
    b = AllenTemporal.interval_of({@t1, @t2})

    assert %Interval.DateTimeInterval{} = a
    assert %Interval.DateTimeInterval{} = b
    assert AllenTemporal.relation(a, b) == :meets
  end
end
