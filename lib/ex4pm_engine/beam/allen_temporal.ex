defmodule Ex4pmEngine.Beam.AllenTemporal do
  @moduledoc """
  Real Allen's interval algebra over `DateTime`-bounded half-open intervals
  `[start, end)`, implemented with plain `DateTime` comparisons — no
  third-party interval package. (Previously backed by the `interval` hex
  package's `Interval.DateTimeInterval`; that package pins `decimal ~> 2.0`
  with no newer release, which is irreconcilable with `explorer`'s
  `decimal ~> 3.1` requirement and would force an unpublishable
  `override: true` dependency. Allen's relations reduce to straightforward
  endpoint comparisons on plain `DateTime` values, so no library was needed
  for this.)

  Given two OCEL-shaped event pairs (each a `{start, end}` `DateTime` tuple),
  computes which one of Allen's 13 base relations holds between them:

  `:before | :after | :meets | :met_by | :overlaps | :overlapped_by |
   :starts | :started_by | :during | :contains | :finishes | :finished_by | :equals`

  Intervals are half-open `[start, end)` (left-inclusive, right-exclusive) —
  the conventional representation for event intervals, under which two
  intervals "meet" exactly when one's end equals the other's start.
  """

  @type interval :: {DateTime.t(), DateTime.t()}

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
  Build a `{start, end}` interval from an OCEL-shaped event pair
  `%{start: DateTime.t(), end: DateTime.t()}` (or a `{start, end}` tuple).
  """
  @spec interval_of(%{start: DateTime.t(), end: DateTime.t()} | interval()) :: interval()
  def interval_of(%{start: start_at, end: end_at}), do: interval_of({start_at, end_at})

  def interval_of({%DateTime{} = start_at, %DateTime{} = end_at}), do: {start_at, end_at}

  @doc """
  Compute the real Allen relation between two `{start, end}` intervals (or
  two OCEL-shaped event pairs, which are converted first).
  """
  @spec relation(
          interval() | %{start: DateTime.t(), end: DateTime.t()},
          interval()
          | %{
              start: DateTime.t(),
              end: DateTime.t()
            }
        ) :: relation()
  def relation({%DateTime{} = a_start, %DateTime{} = a_end}, {
        %DateTime{} = b_start,
        %DateTime{} = b_end
      }) do
    cmp_start = DateTime.compare(a_start, b_start)
    cmp_end = DateTime.compare(a_end, b_end)

    cond do
      DateTime.compare(a_end, b_start) == :eq -> :meets
      DateTime.compare(b_end, a_start) == :eq -> :met_by
      DateTime.compare(a_end, b_start) == :lt -> :before
      DateTime.compare(a_start, b_end) == :gt -> :after
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
