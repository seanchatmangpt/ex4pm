# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.POWL.LanguageTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.POWL
  alias Ex4pmEngine.POWL.ChoiceGraph
  alias Ex4pmEngine.POWL.Language

  test "evaluates exact language of nested POWL 2.0 ChoiceGraph & PartialOrder model" do
    # Nested model: Figure 2b [BPM25 p. 4]
    a = POWL.activity("a", "Check")
    b = POWL.activity("b", "Express")
    c = POWL.activity("c", "Regular")
    d = POWL.activity("d", "Deliver")

    # Choice graph over {a, b, c, d}
    cg_node =
      POWL.choice_graph(
        "cg_order",
        [a, b, c, d],
        [
          {"▷", "a"},
          {"a", "b"},
          {"a", "c"},
          {"b", "d"},
          {"c", "d"},
          {"d", "□"}
        ]
      )

    lang = Language.evaluate(cg_node)

    assert lang == [
             ["Check", "Express", "Deliver"],
             ["Check", "Regular", "Deliver"]
           ]
  end

  test "evaluates partial order concurrency language with order-preserving shuffle" do
    a = POWL.activity("a", "Start")
    b = POWL.activity("b", "ParallelB")
    c = POWL.activity("c", "ParallelC")

    po = POWL.partial_order("po_1", [a, b, c], [{"a", "b"}, {"a", "c"}])
    lang = Language.evaluate(po)

    assert length(lang) == 2
    assert ["Start", "ParallelB", "ParallelC"] in lang
    assert ["Start", "ParallelC", "ParallelB"] in lang
  end

  test "evaluates loop language up to bounded unroll" do
    body = POWL.activity("b", "DoWork")
    redo_t = POWL.activity("r", "FixBug")

    loop_node = POWL.loop("loop_1", body, redo_t)
    lang = Language.evaluate(loop_node, max_unroll: 1)

    assert length(lang) == 2
    assert ["DoWork"] in lang
    assert ["DoWork", "FixBug", "DoWork"] in lang
  end
end
