defmodule Ex4pmEngine.Beam.AllenTemporal do
  @moduledoc """
  Real Allen's interval algebra over `DateTime`-bounded intervals, backed by the
  `interval` hex package (`Interval.DateTimeInterval`).

  Given two OCEL-shaped event pairs (each a `{start, end}` `DateTime` tuple),
  builds two real `Interval.DateTimeInterval` structs and computes which one of
  Allen's 13 base relations holds between them:

  `:before | :after | :meets | :met_by | :overlaps | :overlapped_by |
   :starts | :started_by | :during | :contains | :finishes | :finished_by | :equals`

  Intervals are built with the library's default `"[)"` bounds (left-inclusive,
  right-exclusive) — the conventional half-open representation for event
  intervals, and the one under which `interval`'s own `adjacent_left_of?/2`
  correctly reports "meets" (touching endpoints).
  """

  alias Interval.DateTimeInterval

  @type relation ::
          :before
          | :after
          | :meets
          | :met_by
          | :overlaps
          | :overlapped_by
          | :starts
          | :started_by
          | :during
          | :contains
          | :finishes
          | :finished_by
          | :equals

  @doc """
  Build a real `Interval.DateTimeInterval` from an OCEL-shaped event pair
  `%{start: DateTime.t(), end: DateTime.t()}` (or a `{start, end}` tuple).
  """
  @spec interval_of(%{start: DateTime.t(), end: DateTime.t()} | {DateTime.t(), DateTime.t()}) ::
          Interval.DateTimeInterval.t()
  def interval_of(%{start: start_at, end: end_at}), do: interval_of({start_at, end_at})

  def interval_of({%DateTime{} = start_at, %DateTime{} = end_at}) do
    DateTimeInterval.new(left: start_at, right: end_at)
  end

  @doc """
  Compute the real Allen relation between two `Interval.DateTimeInterval`
  structs (or two OCEL-shaped event pairs, which are converted first).
  """
  @spec relation(
          Interval.DateTimeInterval.t() | %{start: DateTime.t(), end: DateTime.t()},
          Interval.DateTimeInterval.t() | %{start: DateTime.t(), end: DateTime.t()}
        ) :: relation()
  def relation(%DateTimeInterval{} = a, %DateTimeInterval{} = b) do
    a_start = Interval.left(a)
    a_end = Interval.right(a)
    b_start = Interval.left(b)
    b_end = Interval.right(b)

    cmp_start = DateTime.compare(a_start, b_start)
    cmp_end = DateTime.compare(a_end, b_end)

    cond do
      Interval.adjacent_left_of?(a, b) -> :meets
      Interval.adjacent_right_of?(a, b) -> :met_by
      Interval.strictly_left_of?(a, b) -> :before
      Interval.strictly_right_of?(a, b) -> :after
      cmp_start == :eq and cmp_end == :eq -> :equals
      cmp_start == :eq and cmp_end == :lt -> :starts
      cmp_start == :eq and cmp_end == :gt -> :started_by
      cmp_end == :eq and cmp_start == :gt -> :finishes
      cmp_end == :eq and cmp_start == :lt -> :finished_by
      cmp_start == :gt and cmp_end == :lt -> :during
      cmp_start == :lt and cmp_end == :gt -> :contains
      cmp_start == :lt and cmp_end == :lt -> :overlaps
      cmp_start == :gt and cmp_end == :gt -> :overlapped_by
    end
  end

  def relation(a, b), do: relation(interval_of(a), interval_of(b))
end
