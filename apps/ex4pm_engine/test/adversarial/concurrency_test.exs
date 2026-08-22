defmodule Ex4pmEngine.Adversarial.ConcurrencyTest do
  use ExUnit.Case, async: true

  alias Ex4pm.OCEL
  alias Ex4pm.Engine.OnlineMiner

  describe "Concurrent Process Discovery & Mining under High Contention" do
    test "proves multiple parallel agent streams discover identical DFG graphs" do
      events = [
        %{
          "id" => "e1",
          "activity" => "start",
          "timestamp" => "2026-01-01T00:00:00Z",
          "objects" => ["o1"]
        },
        %{
          "id" => "e2",
          "activity" => "verify",
          "timestamp" => "2026-01-01T00:01:00Z",
          "objects" => ["o1"]
        },
        %{
          "id" => "e3",
          "activity" => "complete",
          "timestamp" => "2026-01-01T00:02:00Z",
          "objects" => ["o1"]
        }
      ]

      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            miner_name = :"miner_#{i}_#{System.unique_integer([:positive])}"
            {:ok, pid} = OnlineMiner.start_link(name: miner_name)

            {:ok, log} =
              OCEL.normalize(%{
                "objects" => %{"o_#{i}" => %{"type" => "Order"}},
                "events" =>
                  Map.new(events, fn e ->
                    {"#{e["id"]}_#{i}", Map.put(e, "objects", ["o_#{i}"])}
                  end)
              })

            Enum.each(log.events, &OnlineMiner.ingest(&1, pid))
            OnlineMiner.get_dfg(pid)
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All 10 parallel miners discover identical transition topology: start -> verify -> complete
      first_edges = hd(results).edges
      assert length(results) == 10

      for dfg <- results do
        assert dfg.edges == first_edges
        assert Map.get(dfg.edges, {"start", "verify"}).count == 1
        assert Map.get(dfg.edges, {"verify", "complete"}).count == 1
      end
    end
  end
end
