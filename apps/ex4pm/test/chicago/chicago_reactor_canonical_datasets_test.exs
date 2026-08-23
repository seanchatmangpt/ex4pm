# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Chicago.ChicagoReactorCanonicalDatasetsTest do
  use ExUnit.Case, async: false

  @moduletag :chicago
  @moduletag timeout: 120_000

  alias Ex4pmEngine.Reactors.Chicago.ChicagoProcessIntelligenceReactor

  @fixtures_dir Path.expand("../fixtures", __DIR__)

  setup_all do
    sepsis_path = Path.join(@fixtures_dir, "sepsis.xes")
    domestic_path = Path.join(@fixtures_dir, "domestic_declarations.xes")
    marketplace_path = Path.join(@fixtures_dir, "marketplace-ocel.json")

    {:ok,
     sepsis_content: File.read!(sepsis_path),
     domestic_content: File.read!(domestic_path),
     marketplace_content: File.read!(marketplace_path)}
  end

  describe "1. Canonical Dataset Intelligence via Full Reactor Surface" do
    test "processes Sepsis Event Log through composite sub-reactors, map batches, and analytics",
         %{sepsis_content: content} do
      inputs = [
        filename: "sepsis.xes",
        dataset_content: content,
        mode: :deep_audit,
        audit_tag: "chicago_verification"
      ]

      context = %{
        test_pid: self()
      }

      assert {:ok, manifest} =
               Reactor.run(ChicagoProcessIntelligenceReactor, inputs, context,
                 async?: true,
                 max_concurrency: 8
               )

      # Invariant assertions
      assert manifest.dataset == "sepsis.xes"
      assert manifest.trace_count > 0
      assert manifest.sound? == true
      assert manifest.powl_model != nil
      assert is_binary(manifest.bpmn_xml)
      assert String.contains?(manifest.bpmn_xml, "bpmn:definitions")
      assert manifest.verdict.classification == :deeply_audited
      assert manifest.standing == :alive

      # Verify middleware telemetry events were received
      assert_receive {:step_completed, :audit_group, _}, 5_000
      assert_receive {:audit_group_started, _arguments}, 5_000
      assert_receive {:reactor_completed, ^manifest}, 5_000
    end

    test "processes Domestic Declarations dataset through standard mode switch branch", %{
      domestic_content: content
    } do
      inputs = [
        filename: "domestic_declarations.xes",
        dataset_content: content,
        mode: :standard,
        audit_tag: "chicago_verification"
      ]

      context = %{
        test_pid: self()
      }

      assert {:ok, manifest} =
               Reactor.run(ChicagoProcessIntelligenceReactor, inputs, context,
                 async?: true,
                 max_concurrency: 4
               )

      assert manifest.dataset == "domestic_declarations.xes"
      assert manifest.trace_count > 0
      assert manifest.sound? == true
      assert manifest.verdict.classification == :standard_qualification
      assert manifest.analytics.alignment_fitness >= 0.0
    end

    test "processes Multi-Object Marketplace OCEL dataset with concurrent map transformations",
         %{marketplace_content: content} do
      inputs = [
        filename: "marketplace-ocel.json",
        dataset_content: content,
        mode: :deep_audit,
        audit_tag: "chicago_verification"
      ]

      context = %{
        test_pid: self()
      }

      assert {:ok, manifest} =
               Reactor.run(ChicagoProcessIntelligenceReactor, inputs, context,
                 async?: true,
                 max_concurrency: 8
               )

      assert manifest.dataset == "marketplace-ocel.json"
      assert manifest.trace_count > 0
      assert manifest.sound? == true
      assert manifest.analytics.median_duration_ms > 0
      assert manifest.analytics.anomaly_probability > 0.0
    end
  end
end
