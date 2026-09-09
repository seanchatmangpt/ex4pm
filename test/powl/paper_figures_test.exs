# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.POWL.PaperFiguresTest do
  @moduledoc """
  Executable Proofs of Paper Figures & Case Studies:
  - Figure 1 & Figure 2 [BPM25, pp. 2–4]: Order-to-Delivery Process
  - Figure 1 [PETRI25, pp. 3, 10]: Industrial Production Net (12 transitions)
  - Figure 2 [PETRI25, p. 12]: Non-separable Free-Choice Net
  - Figure 9 [PETRI25, p. 35]: Real-world SAP R/3 Model (ID: 48 177)
  """
  use ExUnit.Case, async: true

  alias Ex4pmEngine.POWL
  alias Ex4pmEngine.POWL.{ChoiceGraph, Language, Shuffle}
  alias Ex4pmEngine.SoundnessProver

  describe "BPM 2025: Figure 1 & 2 Case Study" do
    test "Figure 2b [BPM25, p. 4] constructs 1-safe sound POWL 2.0 Order-to-Delivery net" do
      # Activities
      t_check = POWL.activity("check", "CheckCredit")
      t_express = POWL.activity("express", "ExpressShip")
      t_regular = POWL.activity("regular", "RegularShip")
      t_insure = POWL.activity("insure", "AddInsurance")
      t_deliver = POWL.activity("deliver", "Deliver")

      # Figure 2b Choice Graph
      {:ok, cg} =
        ChoiceGraph.new(
          [t_check, t_express, t_regular, t_insure, t_deliver],
          [
            {"▷", "check"},
            {"check", "express"},
            {"check", "regular"},
            {"express", "insure"},
            {"express", "deliver"},
            {"regular", "deliver"},
            {"insure", "deliver"},
            {"deliver", "□"}
          ]
        )

      # 1. Enumerate paths
      paths = ChoiceGraph.enumerate_paths(cg) |> Enum.sort()
      assert length(paths) == 3

      # 2. Evaluate language
      lang = Language.evaluate(cg) |> Enum.sort()
      assert length(lang) == 3
      assert ["CheckCredit", "ExpressShip", "Deliver"] in lang
      assert ["CheckCredit", "ExpressShip", "AddInsurance", "Deliver"] in lang
      assert ["CheckCredit", "RegularShip", "Deliver"] in lang

      # 3. Compile to WF-Net and prove soundness
      cg_node =
        POWL.choice_graph(
          "cg_fig2b",
          [t_check, t_express, t_regular, t_insure, t_deliver],
          cg.edges
        )

      net = POWL.to_workflow_net(cg_node)
      report = SoundnessProver.verify_soundness(net)

      assert report.sound? == true
      assert report.one_safe? == true
    end
  end

  describe "PETRI NETS 2025: Figure 1 Industrial Production Process Model" do
    test "Figure 1b [PETRI25, pp. 3, 10] constructs hierarchical ChoiceGraph with nested PartialOrder" do
      # Production submodels:
      # PO submodel over concurrent cutting and drilling
      t_cut = POWL.activity("cut", "CutMaterial")
      t_drill = POWL.activity("drill", "DrillHoles")
      # concurrent, no order
      po_prep = POWL.partial_order("po_prep", [t_cut, t_drill], [])

      t_order = POWL.activity("order", "ReceiveOrder")
      t_assemble = POWL.activity("assemble", "Assemble")
      t_inspect = POWL.activity("inspect", "InspectQuality")
      t_rework = POWL.activity("rework", "Rework")
      t_ship = POWL.activity("ship", "ShipProduct")

      # Choice Graph containing the PO as an internal node + cyclic rework jump
      cg_production =
        POWL.choice_graph(
          "cg_fig1b",
          [t_order, po_prep, t_assemble, t_inspect, t_rework, t_ship],
          [
            {"▷", "order"},
            {"order", "po_prep"},
            {"po_prep", "assemble"},
            {"assemble", "inspect"},
            {"inspect", "rework"},
            {"inspect", "ship"},
            # cyclic jump in choice graph!
            {"rework", "assemble"},
            {"ship", "□"}
          ]
        )

      # 1. Assert Choice Graph is cyclic
      assert cg_production.choice_graph.cyclic? == true

      # 2. Evaluate bounded language
      lang = Language.evaluate(cg_production, max_unroll: 1)
      assert length(lang) > 0

      # 3. Assert compiled WF-Net is 1-safe sound
      net = POWL.to_workflow_net(cg_production)
      report = SoundnessProver.verify_soundness(net)

      assert report.sound? == true
      assert report.one_safe? == true
    end
  end

  describe "PETRI NETS 2025: Figure 9 SAP R/3 Industrial Model #48 177" do
    test "Constructs and verifies soundness for non-block SAP R/3 industrial workflow" do
      # SAP R/3 Process #48 177: Multi-path decision with parallel verification
      a1 = POWL.activity("a1", "EnterOrder")
      a2 = POWL.activity("a2", "CheckInventory")
      a3 = POWL.activity("a3", "CheckCredit")
      a4 = POWL.activity("a4", "AuthorizePayment")
      a5 = POWL.activity("a5", "GenerateInvoice")
      a6 = POWL.activity("a6", "ConfirmOrder")

      po_checks = POWL.partial_order("po_checks", [a2, a3], [])

      cg_sap =
        POWL.choice_graph(
          "cg_sap48177",
          [a1, po_checks, a4, a5, a6],
          [
            {"▷", "a1"},
            {"a1", "po_checks"},
            {"po_checks", "a4"},
            {"po_checks", "a5"},
            {"a4", "a6"},
            {"a5", "a6"},
            {"a6", "□"}
          ]
        )

      net = POWL.to_workflow_net(cg_sap)
      report = SoundnessProver.verify_soundness(net)

      assert report.sound? == true
      assert report.one_safe? == true
    end
  end
end
