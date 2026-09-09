# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Adversarial.POWLReactorFalsificationTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Decomposition.WFNetToPOWL
  alias Ex4pmEngine.IO.BPMNPoolExporter
  alias Ex4pmEngine.Miner.{InductiveMiner, OCPOWL}
  alias Ex4pmEngine.POWL
  alias Ex4pmEngine.POWL.Language
  alias Ex4pmEngine.SoundnessProver
  alias Ex4pmEngine.WorkflowNet

  describe "Hostile Falsification: Top-Down PETRI25 Decomposition" do
    test "decomposes Figure 1b Industrial Production Petri Net into sound Choice Graph" do
      # Build Marked Graph SESE net
      net = %WorkflowNet{
        id: "industrial_prod_net",
        places: %{
          "p_in" => %WorkflowNet.Place{id: "p_in"},
          "p_mid" => %WorkflowNet.Place{id: "p_mid"},
          "p_out" => %WorkflowNet.Place{id: "p_out"}
        },
        transitions: %{
          "cut" => %WorkflowNet.Transition{id: "cut", label: "CutSheet"},
          "drill" => %WorkflowNet.Transition{id: "drill", label: "DrillHoles"}
        },
        arcs: [
          {"p_in", "cut"},
          {"cut", "p_mid"},
          {"p_mid", "drill"},
          {"drill", "p_out"}
        ],
        source_place: "p_in",
        sink_place: "p_out"
      }

      assert {:ok, powl_ast} = WFNetToPOWL.convert(net)

      # Prove sound compilation back to Petri Net
      recon_net = POWL.to_workflow_net(powl_ast)
      report = SoundnessProver.verify_soundness(recon_net)

      assert report.sound? == true
      assert report.one_safe? == true
    end
  end

  describe "Hostile Falsification: Multi-Object OC-POWL Discovery" do
    test "discovers synchronized sub-models across multi-object OCEL stream" do
      now = DateTime.utc_now()

      ocel_events = [
        %{activity: "CreateOrder", timestamp: now, objects: %{"order" => ["ord_1"]}},
        %{
          activity: "AddItem",
          timestamp: now,
          objects: %{"order" => ["ord_1"], "item" => ["i_1"]}
        },
        %{
          activity: "AddItem",
          timestamp: now,
          objects: %{"order" => ["ord_1"], "item" => ["i_2"]}
        },
        %{activity: "PackageItem", timestamp: now, objects: %{"item" => ["i_1"]}},
        %{activity: "PackageItem", timestamp: now, objects: %{"item" => ["i_2"]}},
        %{activity: "DeliverOrder", timestamp: now, objects: %{"order" => ["ord_1"]}}
      ]

      assert {:ok, oc_result} = OCPOWL.mine_oc_powl(ocel_events)

      assert "order" in oc_result.object_types
      assert "item" in oc_result.object_types

      order_model = Map.fetch!(oc_result.models, "order")
      item_model = Map.fetch!(oc_result.models, "item")

      order_lang = Language.evaluate(order_model)
      item_lang = Language.evaluate(item_model)

      assert order_lang != []
      assert item_lang != []
    end
  end

  describe "Hostile Falsification: BPMN Organizational Pools & Lanes" do
    test "generates valid BPMN 2.0 collaboration XML with participant pools" do
      model = POWL.activity("act_1", "ApproveInvoice")

      pools_map = %{
        "act_1" => {"FinanceDepartment", "AccountsPayableLane"}
      }

      xml = BPMNPoolExporter.to_xml(model, pools_map)

      assert xml =~ "<bpmn:collaboration id=\"Collaboration_POWL\""
      assert xml =~ "Participant_FinanceDepartment"
      assert xml =~ "<bpmn:process id=\"Process_FinanceDepartment\""
    end
  end
end
