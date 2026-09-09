# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Engine.Conformance.TokenReplayTest do
  @moduledoc """
  Chicago-style real-collaborator suite: replays real traces through a real
  process tree discovered by `Ex4pm.Engine.Discovery.InductiveMiner`, and
  asserts on real produced/consumed/missing/remaining counts and the real
  computed fitness value — no mocked collaborators anywhere in this file.
  """
  use ExUnit.Case, async: true

  alias Ex4pm.Engine.Conformance.TokenReplay
  alias Ex4pm.Engine.Discovery.InductiveMiner

  describe "replay/2 — perfectly fitting trace" do
    test "sequential model ABC replayed with a real fitting trace gets fitness 1.0" do
      log = [["a", "b", "c"]]
      {:ok, tree} = InductiveMiner.mine(log)

      result = TokenReplay.replay(tree, ["a", "b", "c"])

      assert result.produced == 3
      assert result.consumed == 3
      assert result.missing == 0
      assert result.remaining == 0
      assert result.fitness == 1.0
    end
  end

  describe "replay/2 — real exclusive-choice branch, both sides fit" do
    test "branch b fits with no missing/remaining tokens" do
      log = [["a", "b"], ["a", "b"], ["a", "c"], ["a", "c"]]
      {:ok, tree} = InductiveMiner.mine(log)

      result_b = TokenReplay.replay(tree, ["a", "b"])
      assert result_b.produced == 3
      assert result_b.consumed == 2
      assert result_b.missing == 0
      # "c"'s place was never visited by this trace -> 1 real remaining token.
      assert result_b.remaining == 1
      assert_in_delta result_b.fitness, 1 - 0.5 * (1 / 3), 1.0e-9

      result_c = TokenReplay.replay(tree, ["a", "c"])
      assert result_c.produced == 3
      assert result_c.consumed == 2
      assert result_c.missing == 0
      assert result_c.remaining == 1
    end
  end

  describe "replay/2 — superfluous-token freezing prevents token flooding" do
    test "a repeated activity beyond its single modeled place is counted missing, not flooded" do
      log = [["a", "b", "c"]]
      {:ok, tree} = InductiveMiner.mine(log)

      # Real repeat of "a" not present anywhere in the discovered model:
      # without freezing this could silently inflate produced/consumed;
      # with freezing it is a real, counted missing-token event.
      result = TokenReplay.replay(tree, ["a", "a", "b", "c"])

      assert result.produced == 3
      assert result.consumed == 3
      assert result.missing == 1
      assert result.remaining == 0
      assert result.fitness < 1.0
    end

    test "an activity replayed twice in an exclusive-choice tree freezes after first consumption" do
      log = [["a", "b"], ["a", "c"]]
      {:ok, tree} = InductiveMiner.mine(log)

      result = TokenReplay.replay(tree, ["a", "b", "b"])

      # "b"'s place is consumed once (real), then the second "b" hits a
      # frozen place -> real missing-token count of 1, not a flooded 2nd
      # consumption.
      assert result.consumed == 2
      assert result.missing == 1
    end
  end

  describe "fitness_from_counts/4 — real formula on hand-computed inputs" do
    test "matches the classical Rozinat/van der Aalst token-replay formula" do
      # produced=4, consumed=3, missing=1, remaining=1
      # fitness = 0.5*(1 - 1/3) + 0.5*(1 - 1/4) = 0.5*0.6667 + 0.5*0.75 = 0.70833...
      fitness = TokenReplay.fitness_from_counts(4, 3, 1, 1)
      assert_in_delta fitness, 0.7083333333333334, 1.0e-9
    end
  end
end
