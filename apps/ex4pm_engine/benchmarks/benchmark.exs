# Standalone Micro-Benchmark Suite for Ex4pm Process Intelligence Engines
# Run with: mix run apps/ex4pm_engine/benchmarks/benchmark.exs

alias Ex4pmEngine.StreamingEngine
alias Ex4pmEngine.Alignment
alias Ex4pmEngine.SoundnessProver
alias Ex4pmEngine.Cognition.Survival

ocel_path = "/Users/sac/xaas/priv/ocel/ash-actions.ndjson"

IO.puts("""
========================================================================
       EX4PM PROCESS INTELLIGENCE BENCHMARK SUITE (BENCHEE)
========================================================================
""")

# Sample Workflow Net for Alignment
net_spec = %{
  transitions: %{
    request: %{inputs: ["p_in"], outputs: ["p_1"], label: "request"},
    approve: %{inputs: ["p_1"], outputs: ["p_2"], label: "approve"},
    deploy: %{inputs: ["p_2"], outputs: ["p_out"], label: "deploy"}
  },
  initial_marking: ["p_in"],
  final_marking: ["p_out"]
}

trace = ["request", "approve", "deploy"]

# 10k synthetic durations for Survival Analysis
durations = Enum.map(1..10_000, fn _ -> :rand.uniform(30_000) + 5_000 end)
survival_model = Survival.fit_kaplan_meier(durations)

# Measure individual operations
{t_stream_us, stream_res} =
  if File.exists?(ocel_path) do
    :timer.tc(fn ->
      StreamingEngine.process_file(ocel_path, chunk_size: 10_000, max_concurrency: 8)
    end)
  else
    {0, %{total_events: 0, throughput_events_sec: 0.0}}
  end

{t_align_us, _} =
  :timer.tc(fn ->
    Enum.each(1..1000, fn _ -> Alignment.align_trace(trace, net_spec) end)
  end)

{:ok, single_align} = Alignment.align_trace(trace, net_spec)

{t_sound_us, _} =
  :timer.tc(fn ->
    Enum.each(1..1000, fn _ -> SoundnessProver.verify_soundness(net_spec) end)
  end)

single_sound = SoundnessProver.verify_soundness(net_spec)

{t_surv_us, _} =
  :timer.tc(fn ->
    Enum.each(1..10_000, fn i -> Survival.predict_remaining_time(survival_model, i * 2) end)
  end)

IO.puts("""
------------------------------------------------------------------------
1. StreamingEngine Ingest Throughput (647k Production Events):
   - Total Events:      #{stream_res.total_events}
   - Ingest Latency:    #{Float.round(t_stream_us / 1000.0, 2)} ms
   - Peak Throughput:   #{round(stream_res.total_events / max(0.001, t_stream_us / 1_000_000.0))} events / sec

2. A* Optimal Alignment (1,000 Iterations):
   - Total Time:        #{Float.round(t_align_us / 1000.0, 2)} ms
   - Rate:              #{round(1000 / (t_align_us / 1_000_000.0))} alignments / sec
   - Alignment Fitness: #{single_align.fitness}

3. Reachability Soundness Prover (1,000 Verifications):
   - Total Time:        #{Float.round(t_sound_us / 1000.0, 2)} ms
   - Rate:              #{round(1000 / (t_sound_us / 1_000_000.0))} proofs / sec
   - 1-Safe Sound?:     #{single_sound.sound?}

4. Kaplan-Meier RUL Prediction (10,000 Predictions):
   - Total Time:        #{Float.round(t_surv_us / 1000.0, 2)} ms
   - Rate:              #{round(10_000 / (t_surv_us / 1_000_000.0))} predictions / sec
------------------------------------------------------------------------
""")
