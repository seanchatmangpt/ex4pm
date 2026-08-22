defmodule Ex4pmEngine.POWLTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Refusal
  alias Ex4pmEngine.POWL
  alias Ex4pmEngine.WorkflowNet

  test "constructs recursive POWL 2.0 terms from nested Elixir values" do
    create = POWL.activity("create", "Create Order")
    approve = POWL.activity("approve", "Approve Order")
    reject = POWL.activity("reject", "Reject Order")
    ship = POWL.activity("ship", "Ship Goods")

    decision = POWL.choice("decision", [approve, reject])
    root = POWL.sequence("root", [create, decision, ship])

    assert {:ok, model} = POWL.new(root)
    assert model.root == "root"
    assert map_size(model.nodes) == 6
    assert model.subject.kind == :powl_model

    assert {:ok, language} = POWL.language(model)

    assert language == [
             ["Create Order", "Approve Order", "Ship Goods"],
             ["Create Order", "Reject Order", "Ship Goods"]
           ]

    assert POWL.accepts?(model, ["Create Order", "Approve Order", "Ship Goods"])
    refute POWL.accepts?(model, ["Create Order", "Ship Goods", "Approve Order"])
  end

  test "structurally identical terms manufacture the same default subject identity" do
    left = POWL.sequence("root", [POWL.activity("a", "A"), POWL.activity("b", "B")])
    right = POWL.sequence("root", [POWL.activity("a", "A"), POWL.activity("b", "B")])

    assert {:ok, left_model} = POWL.new(left)
    assert {:ok, right_model} = POWL.new(right)

    assert left_model.id == "powl:root"
    assert left_model.subject.hash == right_model.subject.hash
  end

  test "binary loop is the cyclic POWL 2.0 choice-graph mapping" do
    body = POWL.activity("body", "A")
    redo_node = POWL.activity("redo", "B")
    loop = POWL.loop("loop", body, redo_node)

    assert loop.type == :choice

    assert MapSet.new(loop.choice_graph.edges) ==
             MapSet.new([
               {POWL.choice_start(), "body"},
               {"body", POWL.choice_end()},
               {"body", "redo"},
               {"redo", "body"}
             ])

    assert {:ok, model} = POWL.new(loop)

    assert {:ok, language} = POWL.language(model, max_loop_iterations: 2)

    assert language == [
             ["A"],
             ["A", "B", "A"],
             ["A", "B", "A", "B", "A"]
           ]
  end

  test "choice graph language follows complete directed paths rather than branch conflict edges" do
    a = POWL.activity("a", "A")
    b = POWL.activity("b", "B")
    c = POWL.activity("c", "C")

    graph =
      POWL.choice_graph(
        "g",
        [a, b, c],
        [
          {POWL.choice_start(), "a"},
          {"a", "b"},
          {"b", POWL.choice_end()},
          {POWL.choice_start(), "c"},
          {"c", POWL.choice_end()}
        ]
      )

    assert {:ok, model} = POWL.new(graph)
    assert {:ok, language} = POWL.language(model)
    assert language == [["A", "B"], ["C"]]
  end

  test "explicit empty directed choice graph is refused rather than normalized to XOR" do
    a = POWL.activity("a", "A")
    b = POWL.activity("b", "B")
    graph = POWL.choice_graph("g", [a, b], [])

    assert {:error, %Refusal{code: :invalid_choice_graph}} = POWL.new(graph)
  end

  test "order-preserving shuffle matches the POWL 2.0 paper example at event level" do
    a = POWL.activity("a", "a")
    b = POWL.activity("b", "b")
    c = POWL.activity("c", "c")
    d = POWL.activity("d", "d")
    e = POWL.activity("e", "e")

    sigma1 = POWL.sequence("sigma1", [a, b])
    sigma3 = POWL.sequence("sigma3", [d, e])

    root =
      POWL.partial_order(
        "root",
        [sigma1, c, sigma3],
        [{"sigma1", "c"}, {"sigma1", "sigma3"}]
      )

    assert {:ok, model} = POWL.new(root)
    assert {:ok, language} = POWL.language(model)

    assert language == [
             ["a", "b", "c", "d", "e"],
             ["a", "b", "d", "c", "e"],
             ["a", "b", "d", "e", "c"]
           ]
  end

  test "transitively closes strict partial-order relations" do
    a = POWL.activity("a", "A")
    b = POWL.activity("b", "B")
    c = POWL.activity("c", "C")

    root = POWL.partial_order("root", [a, b, c], [{"a", "b"}, {"b", "c"}])

    assert {"a", "c"} in root.edges
    assert {:ok, _model} = POWL.new(root)
  end

  test "compiles nested POWL choice and partial order into a sound 1-safe WorkflowNet" do
    a = POWL.activity("a", "A")
    b = POWL.activity("b", "B")
    c = POWL.activity("c", "C")
    d = POWL.activity("d", "D")

    choice = POWL.choice("choice", [b, c])
    root = POWL.sequence("root", [a, choice, d])

    assert {:ok, powl_model} = POWL.new(root)
    assert {:ok, wf_net} = POWL.to_workflow_net(powl_model)

    assert :ok = WorkflowNet.validate_structure(wf_net)
    assert {:ok, report} = WorkflowNet.verify_soundness(wf_net)
    assert report.sound?
    assert report.one_safe?
    assert report.option_to_complete?
    assert report.proper_completion?
  end

  test "refuses a cyclic strict partial order" do
    a = POWL.activity("a", "A")
    b = POWL.activity("b", "B")
    root = POWL.partial_order("root", [a, b], [{"a", "b"}, {"b", "a"}])

    assert {:error, %Refusal{code: :cyclic_powl_node}} = POWL.new(root)
  end

  test "refuses a malformed choice graph with a child outside every source-to-sink path" do
    a = POWL.activity("a", "A")
    b = POWL.activity("b", "B")

    graph =
      POWL.choice_graph(
        "g",
        [a, b],
        [
          {POWL.choice_start(), "a"},
          {"a", POWL.choice_end()}
        ]
      )

    assert {:error, %Refusal{code: :invalid_choice_graph}} = POWL.new(graph)
  end
end
