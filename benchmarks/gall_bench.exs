# GALL v26.9.18 process-law benchmark (deterministic workloads, :timer.tc).
# Run: MIX_ENV=test mix run benchmarks/gall_bench.exs [--json PATH]
#
# Workloads and regression bounds are shared with
# test/gall_v26_9_18_bench_test.exs via Ex4pm.GallBench (below), so the
# committed receipt and the CI guard measure the same thing.

defmodule Ex4pm.GallBench.Script do
  defp loadavg do
    case System.cmd("uptime", []) do
      {out, 0} -> out |> String.split(~r/load averages?:/) |> List.last() |> String.trim()
      _ -> "unknown"
    end
  rescue
    _ -> "unknown"
  end

  # Commit the measured tree descends from: GALL_BENCH_PARENT_SHA when set
  # (scratch trees without .git), else `git rev-parse HEAD`.
  defp parent_commit do
    case System.get_env("GALL_BENCH_PARENT_SHA") do
      sha when is_binary(sha) and sha != "" ->
        sha

      _ ->
        case System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true) do
          {out, 0} -> String.trim(out)
          _ -> "unknown"
        end
    end
  rescue
    _ -> "unknown"
  end

  def main(argv) do
    {opts, _, _} = OptionParser.parse(argv, strict: [json: :string, runs: :integer])
    runs = Keyword.get(opts, :runs, 31)

    results =
      for {name, fun} <- Ex4pm.GallBench.workloads() do
        stats = Ex4pm.GallBench.measure(fun, runs)
        bound = Ex4pm.GallBench.bounds_us()[name]

        IO.puts(
          String.pad_trailing(to_string(name), 26) <>
            "median #{stats.median_us}us  p90 #{stats.p90_us}us  min #{stats.min_us}us  bound #{bound}us"
        )

        {to_string(name), Map.put(stats, :bound_us, bound)}
      end
      |> Map.new()

    if path = opts[:json] do
      receipt = %{
        "schema" => "ex4pm.gall.bench/v26.9.26",
        "otp" => System.otp_release(),
        "elixir" => System.version(),
        "runs" => runs,
        "loadavg" => loadavg(),
        "subject" => %{
          "parent_commit" => parent_commit(),
          "source_digests" => Ex4pm.GallBench.source_digests()
        },
        "results" => results
      }

      File.write!(path, Jason.encode!(receipt, pretty: true) <> "\n")
      IO.puts("wrote #{path}")
    end
  end
end

Ex4pm.GallBench.Script.main(System.argv())
