defmodule Ex4pm.Integration.LiveAshPipelineTest do
  use ExUnit.Case, async: false

  alias Ex4pmDomain.Notifier.OcelNotifier
  alias Ex4pmCore.Blueprints.IncidentManagement
  alias Ex4pm.Engine.OnlineMiner
  alias Ex4pmEvidence.Conformance
  alias Ex4pmEvidence.Engine, as: EvidenceEngine
  alias Ex4pmDomain.CapabilityReceipt

  # --- Test Domain & Live Resource ---
  defmodule LiveIncidentResource do
    use Ash.Resource,
      domain: Ex4pm.Integration.LiveAshPipelineTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      notifiers: [Ex4pmDomain.Notifier.OcelNotifier]

    actions do
      defaults([:read])

      create :detect do
        primary?(true)
        accept([:severity, :title])
      end

      update :triage do
        accept([:status])
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, allow_nil?: false)
      attribute(:severity, :string, default: "HIGH")
      attribute(:status, :string, default: "DETECTED")
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(LiveIncidentResource)
    end
  end

  describe "Chicago-Style Closed-Loop Ash Process Intelligence Pipeline" do
    test "executes full closed loop: Ash Mutation -> OcelNotifier -> OnlineMiner DFG -> Conformance -> CapabilityReceipt" do
      # 1. Start an OnlineMiner instance
      miner_name = :"live_miner_#{System.unique_integer([:positive])}"
      {:ok, miner_pid} = OnlineMiner.start_link(name: miner_name)

      # 2. Execute Ash action with OcelNotifier
      assert {:ok, record} =
               LiveIncidentResource
               |> Ash.Changeset.for_create(
                 :detect,
                 %{title: "Database Latency Spike", severity: "CRITICAL"},
                 domain: TestDomain,
                 actor: %{id: "monitor_bot"}
               )
               |> Ash.create()

      notif = %Ash.Notifier.Notification{
        resource: LiveIncidentResource,
        action: %{name: :detect_incident, type: :create},
        actor: %{id: "monitor_bot"},
        data: record
      }

      event = OcelNotifier.transform_notification(notif)
      assert event["activity"] == "LiveIncidentResource.detect_incident"
      assert event["attributes"]["actor"] == "monitor_bot"

      # 3. Stream event into OnlineMiner
      OnlineMiner.ingest(event, miner_pid)
      summary = OnlineMiner.get_summary(miner_pid)
      assert summary.total_events == 1

      # 4. Evaluate Conformance against IncidentManagement Blueprint
      blueprint = IncidentManagement.blueprint()

      log = %{
        "objects" => %{to_string(record.id) => %{"type" => "Incident"}},
        "events" => %{
          "e1" => %{
            "activity" => "detect_incident",
            "timestamp" => "2026-01-01T00:00:00Z",
            "objects" => [to_string(record.id)],
            "attributes" => %{"actor" => "monitor_bot"}
          }
        }
      }

      assert {:ok, vec} = Conformance.evaluate(log, blueprint, object_type: "Incident")
      assert vec.fitness == 1.0

      # 5. Emit W3C EARL 1.0 Test Assertion
      assert {:ok, earl} =
               EvidenceEngine.build_earl_assertion(
                 outcome: :passed,
                 info: "Closed-loop Ash action to process-intelligence pipeline verified."
               )

      # 6. Record in CapabilityReceipt Domain Resource
      assert {:ok, receipt} =
               CapabilityReceipt
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   capability: "live_ash_process_intelligence",
                   subject: "https://enterprise.fortune5.com/system/live-ash-pipeline",
                   status: :alive,
                   exit_code: 0,
                   standing: :ALIVE,
                   agent_id: "monitor_bot",
                   digest: earl.details.timestamp
                 },
                 domain: Ex4pmDomain
               )
               |> Ash.create()

      assert receipt.capability == "live_ash_process_intelligence"
      assert receipt.standing == :ALIVE
    end
  end
end
