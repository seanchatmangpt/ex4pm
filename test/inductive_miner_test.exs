# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.InductiveMinerTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.InductiveMiner
  alias Ex4pmEngine.POWL.{ChoiceGraph, Language}
  alias Ex4pmEngine.SoundnessProver

  describe "BPM 2025: Theorem 1 Fitness Guarantee & Choice Graph Cut" do
    test "discovers sound non-block choice graph from Order-to-Delivery trace log" do
      # Traces from running example: Figure 1 & 2 [BPM25, p. 2-4]
      log = [
        ["CheckCredit", "ExpressShip", "Deliver"],
        ["CheckCredit", "ExpressShip", "AddInsurance", "Deliver"],
        ["CheckCredit", "RegularShip", "Deliver"],
        ["CheckCredit", "ExpressShip", "Deliver"],
        ["CheckCredit", "RegularShip", "Deliver"]
      ]

      assert {:ok, model} = InductiveMiner.mine(log)

      # 1. Theorem 1 Fitness Guarantee: Every trace in log must be in L(model)
      model_lang = Language.evaluate(model)

      for trace <- log do
        assert trace in model_lang, "Trace #{inspect(trace)} must be in discovered model language"
      end

      # 2. Soundness: Must produce a 1-safe sound Workflow Net
      wf_net = Ex4pmEngine.POWL.to_workflow_net(model)
      report = SoundnessProver.verify_soundness(wf_net)

      assert report.sound? == true
      assert report.one_safe? == true
    end

    test "Algorithm 1 MineDG partitions mutually reachable DFG activities" do
      dfg = MapSet.new([{"a", "b"}, {"b", "a"}, {"b", "c"}, {"c", "d"}])
      sigma_l = ["a", "b", "c", "d"]

      parts = InductiveMiner.mine_dg(dfg, sigma_l)

      assert length(parts) == 3
      assert MapSet.new(["a", "b"]) in parts
      assert MapSet.new(["c"]) in parts
      assert MapSet.new(["d"]) in parts
    end
  end
end
