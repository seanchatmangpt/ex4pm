defmodule Ex4pmEvidence.EngineTest do
  use ExUnit.Case, async: true

  alias Ex4pmEvidence.Engine

  describe "1. W3C EARL 1.0 Assertion Generator" do
    test "generates valid EARL passed assertion" do
      assert {:ok, result} =
               Engine.build_earl_assertion(
                 outcome: :passed,
                 info: "All 1-safe soundness invariants satisfied."
               )

      assert result.outcome == :passed
      assert String.contains?(result.turtle, "earl:Assertion")
      assert String.contains?(result.turtle, "earl:TestResult")
      assert String.contains?(result.turtle, "earl:passed")
    end

    test "generates valid EARL failed assertion with diagnostic info" do
      assert {:ok, result} =
               Engine.build_earl_assertion(
                 outcome: :failed,
                 info: "Deadlock detected at non-terminal marking."
               )

      assert result.outcome == :failed
      assert String.contains?(result.turtle, "earl:failed")
      assert String.contains?(result.turtle, "Deadlock detected")
    end
  end

  describe "2. W3C SOSA / SSN + QUDT Observation Generator" do
    test "generates SOSA observation with QUDT millisecond latency" do
      assert {:ok, obs} =
               Engine.build_sosa_observation(
                 observed_property: "https://enterprise.fortune5.com/ontology/P99Latency",
                 numeric_value: 18.4
               )

      assert obs.numeric_value == 18.4
      assert String.contains?(obs.turtle, "sosa:Observation")
      assert String.contains?(obs.turtle, "qudt:QuantityValue")
      assert String.contains?(obs.turtle, "18.4")
      assert String.contains?(obs.turtle, "MilliSEC")
    end
  end

  describe "3. W3C PROV-O Lineage Generator" do
    test "generates PROV-O execution lineage linking agent, activity, and entities" do
      assert {:ok, lin} =
               Engine.build_prov_lineage(
                 agent: "https://enterprise.fortune5.com/ontology/agent/fly-worker-01"
               )

      assert String.contains?(lin.turtle, "prov:Activity")
      assert String.contains?(lin.turtle, "prov:Entity")
      assert String.contains?(lin.turtle, "prov:wasAssociatedWith")
      assert String.contains?(lin.turtle, "prov:wasDerivedFrom")
    end
  end

  describe "4. W3C DCAT 3 Catalog Record Generator" do
    test "generates DCAT 3 catalog dataset record" do
      assert {:ok, dcat} =
               Engine.build_dcat_catalog_record(title: "Real-Time Agent Fleet OCEL Stream")

      assert String.contains?(dcat.turtle, "dcat:Catalog")
      assert String.contains?(dcat.turtle, "dcat:Dataset")
      assert String.contains?(dcat.turtle, "dcat:Distribution")
      assert String.contains?(dcat.turtle, "Real-Time Agent Fleet OCEL Stream")
    end
  end

  describe "5. SPDX 3.0 Package Manifest Generator" do
    test "generates SPDX cryptographic SBOM package digest" do
      assert {:ok, spdx} =
               Engine.build_spdx_manifest(
                 name: "ex4pm_core",
                 version: "0.1.0"
               )

      assert is_binary(spdx.digest)
      assert String.length(spdx.digest) == 64
      assert String.contains?(spdx.turtle, "spdx:Package")
      assert String.contains?(spdx.turtle, "spdx:checksumAlgorithm_sha256")
    end
  end
end
