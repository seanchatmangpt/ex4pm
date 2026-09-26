defmodule Ex4pm.GallBenchTest do
  @moduledoc """
  Regression bound for the GALL v26.9.18 benchmark workloads
  (Ex4pm.GallBench, recorded by benchmarks/gall_bench.exs into
  benchmarks/gall_v26_9_18_bench_receipt.json). Real workloads, real clock.
  """
  use ExUnit.Case, async: false

  alias Ex4pm.GallBench

  @receipt Path.expand("../benchmarks/gall_v26_9_18_bench_receipt.json", __DIR__)

  test "every workload stays under its committed regression bound" do
    for {name, fun} <- GallBench.workloads() do
      %{median_us: median} = GallBench.measure(fun, 7)
      bound = GallBench.bounds_us()[name]
      assert median <= bound, "#{name}: median #{median}us exceeds bound #{bound}us"
    end
  end

  test "committed bench receipt covers every workload and records bounds consistent with the guard" do
    receipt = @receipt |> File.read!() |> Jason.decode!()
    assert receipt["schema"] == "ex4pm.gall.bench/v26.9.26"

    names = GallBench.workloads() |> Keyword.keys() |> Enum.map(&to_string/1) |> Enum.sort()
    assert receipt["results"] |> Map.keys() |> Enum.sort() == names

    # min_us is the least load-sensitive statistic on a shared host
    for {name, %{"min_us" => min, "median_us" => median, "bound_us" => bound}} <-
          receipt["results"] do
      assert bound == GallBench.bounds_us()[String.to_existing_atom(name)]
      assert median <= bound, "#{name}: recorded median #{median}us exceeds its own bound"
      assert min * 5 <= bound, "#{name}: recorded min #{min}us leaves < 5x headroom"
    end
  end
end
