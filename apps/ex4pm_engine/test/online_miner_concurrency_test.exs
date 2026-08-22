defmodule Ex4pm.Engine.OnlineMinerConcurrencyTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Engine.OnlineMiner
  alias Ex4pm.Event

  setup do
    {:ok, miner} = start_supervised({OnlineMiner, [name: :stress_online_miner]})
    %{miner: miner}
  end

  test "concurrently ingests 1,000 events across 20 parallel agent workers without dropping events or deadlocking",
       %{
         miner: miner
       } do
    agent_count = 20
    events_per_agent = 50
    total_expected = agent_count * events_per_agent

    tasks =
      for agent_idx <- 1..agent_count do
        Task.async(fn ->
          agent_id = "stress-agent-#{agent_idx}"
          run_id = "run-stress-#{agent_idx}"

          Enum.each(1..events_per_agent, fn seq ->
            activity =
              case rem(seq, 5) do
                0 -> "admit"
                1 -> "construct"
                2 -> "verify"
                3 -> "brce"
                4 -> "do"
              end

            event = %Event{
              id: "ev-#{agent_idx}-#{seq}",
              activity: activity,
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
              attributes: %{
                "agent_id" => agent_id,
                "run_id" => run_id,
                "sequence" => seq,
                "standing" => :alive
              }
            }

            :ok = OnlineMiner.ingest(event, miner)
          end)
        end)
      end

    Enum.each(tasks, &Task.await(&1, 5000))

    summary = OnlineMiner.get_summary(miner)
    assert summary.total_events == total_expected
    assert summary.total_agents == agent_count

    fleet = OnlineMiner.get_fleet_status(miner)
    assert length(fleet) == agent_count

    dfg = OnlineMiner.get_dfg(miner)
    assert map_size(dfg.edges) > 0
    assert dfg.trace_count == agent_count
  end
end
