defmodule Ex4pm.Engine.OnlineMinerTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Engine.OnlineMiner
  alias Ex4pm.Event

  setup do
    # Start OnlineMiner uniquely per test
    {:ok, miner} = start_supervised({OnlineMiner, [name: :test_online_miner]})
    %{miner: miner}
  end

  test "ingests single event and updates fleet & activity statistics", %{miner: miner} do
    event = %Event{
      id: "ev-01",
      activity: "admit",
      timestamp: "2026-08-21T18:00:00Z",
      attributes: %{
        "agent_id" => "agent-42",
        "run_id" => "run-101",
        "standing" => :alive,
        "repository" => "ash_r2rml"
      }
    }

    assert :ok = OnlineMiner.ingest(event, miner)

    summary = OnlineMiner.get_summary(miner)
    assert summary.total_events == 1
    assert summary.active_agents == 1

    fleet = OnlineMiner.get_fleet_status(miner)
    assert length(fleet) == 1
    agent = hd(fleet)
    assert agent.agent_id == "agent-42"
    assert agent.last_activity == "admit"
    assert agent.repository == "ash_r2rml"
  end

  test "computes online DFG transitions and average durations", %{miner: miner} do
    e1 = %Event{
      id: "ev-01",
      activity: "admit",
      timestamp: "2026-08-21T18:00:00Z",
      attributes: %{"agent_id" => "agent-01", "run_id" => "run-1"}
    }

    e2 = %Event{
      id: "ev-02",
      activity: "construct",
      timestamp: "2026-08-21T18:00:05Z",
      attributes: %{"agent_id" => "agent-01", "run_id" => "run-1"}
    }

    assert :ok = OnlineMiner.ingest(e1, miner)
    assert :ok = OnlineMiner.ingest(e2, miner)

    dfg = OnlineMiner.get_dfg(miner)
    assert map_size(dfg.edges) == 1

    edge_stats = Map.get(dfg.edges, {"admit", "construct"})
    assert edge_stats != nil
    assert edge_stats.count == 1
    assert edge_stats.average_duration_ms == 5000.0
  end

  test "detects non-conformant transitions and updates fitness", %{miner: miner} do
    # Lawful: admit -> construct
    e1 = %Event{
      id: "ev-01",
      activity: "admit",
      timestamp: "2026-08-21T18:00:00Z",
      attributes: %{"agent_id" => "agent-01", "run_id" => "run-1"}
    }

    # Skipping directly to do (violates admit -> construct -> verify -> brce -> do)
    # backward violation: standing -> admit
    e2 = %Event{
      id: "ev-02",
      activity: "standing",
      timestamp: "2026-08-21T18:00:01Z",
      attributes: %{"agent_id" => "agent-01", "run_id" => "run-1"}
    }

    e3 = %Event{
      id: "ev-03",
      activity: "admit",
      timestamp: "2026-08-21T18:00:02Z",
      attributes: %{"agent_id" => "agent-01", "run_id" => "run-1"}
    }

    OnlineMiner.ingest(e1, miner)
    OnlineMiner.ingest(e2, miner)
    OnlineMiner.ingest(e3, miner)

    conformance = OnlineMiner.get_conformance(miner)
    assert conformance.observed_transitions == 2
    assert conformance.non_conformant_transitions == 1
    assert conformance.fitness < 1.0
  end

  test "tracks typed refusals in the refusal radar", %{miner: miner} do
    refusal_event = %Event{
      id: "ev-refuse-01",
      activity: "REFUSED_NO_AUTHORITY",
      timestamp: "2026-08-21T18:10:00Z",
      attributes: %{
        "agent_id" => "agent-99",
        "run_id" => "run-99",
        "standing" => :refused,
        "reason" => "DO callback requires explicit BRCE authority token"
      }
    }

    OnlineMiner.ingest(refusal_event, miner)

    summary = OnlineMiner.get_summary(miner)
    assert summary.refusal_count == 1

    conformance = OnlineMiner.get_conformance(miner)
    assert length(conformance.recent_refusals) == 1
    refusal = hd(conformance.recent_refusals)
    assert refusal.agent_id == "agent-99"
    assert refusal.activity == "REFUSED_NO_AUTHORITY"
  end
end
