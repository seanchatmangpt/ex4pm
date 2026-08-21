defmodule Ex4pm.DomainTest do
  use ExUnit.Case, async: false

  test "canonical datasets and engine capabilities project into Ash ETS resources" do
    raw = %{
      "objects" => %{"o1" => %{"type" => "Order"}},
      "events" => %{
        "e1" => %{
          "activity" => "create",
          "timestamp" => "2026-01-01T00:00:00Z",
          "objects" => ["o1"]
        }
      }
    }

    assert {:ok, log} = Ex4pm.OCEL.normalize(raw)
    assert {:ok, dataset} = Ex4pm.Domain.Projector.dataset(log)
    assert dataset.subject_hash == log.subject.hash
    assert dataset.event_count == 1

    capability =
      Ex4pm.Engine.Registry.candidates(:discover)
      |> Enum.find(&(&1.id == :beam))

    assert {:ok, projected} = Ex4pm.Domain.Projector.capability(capability)
    assert projected.engine == :beam
    assert projected.standing == :alive
  end
end
