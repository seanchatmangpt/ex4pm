defmodule Ex4pm.GallBench do
  @moduledoc """
  Deterministic GALL v26.9.18 benchmark workloads and regression bounds.

  Bounds are microseconds for the median of N runs, set at >= 5x the minimum
  times recorded in `benchmarks/gall_v26_9_18_bench_receipt.json` (recorded on a
  heavily loaded host; see its `loadavg`), so a slower CI runner passes but
  an algorithmic regression fails. Example: the original iterated pairwise
  transitive closure needs ~log2(n) passes of O(E^2) joins over a closure that
  grows to ~80k pairs for `wfnet(200)` -- orders of magnitude over the bound.
  """

  alias Ex4pm.Gall.{Corpus, Discovery, Ocpq, Portable, Powl}

  @sha "5abf57f91e85628a605a1dacace2a50e43fabb8b"

  def bounds_us do
    %{
      wfnet_200_via_places: 1_500_000,
      portable_build_verify: 1_500_000,
      ocpq_2000_events: 300_000,
      discover_1000_traces: 100_000,
      canonical_json_10k: 800_000
    }
  end

  def workloads do
    wfnet = wfnet(200)
    {:ok, powl} = Powl.from_wfnet(wfnet)
    ocel = ocel(2000)
    traces = traces(1000)
    payload = Map.new(1..10_000, &{"k#{&1}", &1})

    [
      wfnet_200_via_places: fn -> {:ok, _} = Powl.from_wfnet(wfnet) end,
      portable_build_verify: fn ->
        {:ok, artifact} =
          Portable.build(:powl, powl,
            repository: "seanchatmangpt/ex4pm",
            producer_sha: @sha,
            corpus_digest: Corpus.manifest_digest()
          )

        {:ok, _} = Portable.verify(artifact)
      end,
      ocpq_2000_events: fn ->
        {:ok, _} =
          Ocpq.evaluate(ocel, %{activity: "ship", object_type: "item", after_activity: "create"})
      end,
      discover_1000_traces: fn ->
        {:ok, _} = Discovery.discover(traces, [{:before, "a", "d"}, {:require_edge, "a", "b"}])
      end,
      canonical_json_10k: fn -> Portable.digest(payload) end
    ]
  end

  def measure(fun, runs) do
    fun.()

    samples =
      for _ <- 1..runs do
        {us, _} = :timer.tc(fun)
        us
      end
      |> Enum.sort()

    %{
      median_us: Enum.at(samples, div(runs, 2)),
      p90_us: Enum.at(samples, min(runs - 1, div(runs * 9, 10))),
      min_us: hd(samples)
    }
  end

  # a -> p_a -> b -> p_b -> ... : a 200-transition sequence routed through places
  def wfnet(n) do
    transitions = for i <- 1..n, do: "t#{i}"

    flow =
      for i <- 1..(n - 1), arc <- [{"t#{i}", "p#{i}"}, {"p#{i}", "t#{i + 1}"}], do: arc

    %{transitions: transitions, flow: flow}
  end

  def ocel(n) do
    events =
      for i <- 1..n do
        activity = if rem(i, 2) == 1, do: "create", else: "ship"

        %{
          id: "e#{i}",
          activity: activity,
          sequence: i,
          objects: [
            {"order:#{div(i + 1, 2)}", "order", "target"},
            {"item:#{i}", "item", "contains"}
          ]
        }
      end

    %{events: events}
  end

  def traces(n) do
    variants = [["a", "b", "c", "d"], ["a", "b", "d"], ["a", "c", "b", "d"]]
    for i <- 1..n, do: Enum.at(variants, rem(i, 3))
  end
end
