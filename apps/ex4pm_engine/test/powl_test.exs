defmodule Ex4pmEngine.POWLTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.POWL
  alias Ex4pmEngine.WorkflowNet
  alias Ex4pm.Refusal

  test "constructs and validates POWL 2.0 partial order, choice, and loop models" do
    act_a = POWL.activity("a", "Create Order")
    act_b = POWL.activity("b", "Approve Order")
    act_c = POWL.activity("c", "Reject Order")
    act_d = POWL.activity("d", "Ship Goods")

    choice_node = POWL.choice("choice_1", [act_b, act_c])

    po_node =
      POWL.partial_order("po_1", [act_a, choice_node, act_d], [
        {"a", "choice_1"},
        {"choice_1", "d"}
      ])

    all_nodes = %{
      "a" => act_a,
      "b" => act_b,
      "c" => act_c,
      "d" => act_d,
      "choice_1" => choice_node,
      "po_1" => po_node
    }

    assert {:ok, model} = POWL.new(all_nodes, root: "po_1")
    assert model.root == "po_1"
    assert map_size(model.nodes) == 6
    assert model.subject.kind == :powl_model

    # Language preservation tests
    assert {:ok, language} = POWL.language(model)
    assert ["Create Order", "Approve Order", "Ship Goods"] in language
    assert ["Create Order", "Reject Order", "Ship Goods"] in language
    assert length(language) == 2

    assert POWL.accepts?(model, ["Create Order", "Approve Order", "Ship Goods"])
    refute POWL.accepts?(model, ["Create Order", "Ship Goods", "Approve Order"])
  end

  test "generates language for loop nodes up to max_loop_iterations" do
    act_body = POWL.activity("body", "Execute Task")
    act_redo = POWL.activity("redo", "Retry Task")
    loop_node = POWL.loop("loop_1", act_body, act_redo)

    nodes = %{
      "body" => act_body,
      "redo" => act_redo,
      "loop_1" => loop_node
    }

    assert {:ok, model} = POWL.new(nodes, root: "loop_1")
    assert {:ok, language} = POWL.language(model, max_loop_iterations: 2)

    assert ["Execute Task"] in language
    assert ["Execute Task", "Retry Task", "Execute Task"] in language

    assert ["Execute Task", "Retry Task", "Execute Task", "Retry Task", "Execute Task"] in language
  end

  test "generalized choice graph supports non-free-choice and branch exclusivity" do
    act_1 = POWL.activity("x1", "Branch 1")
    act_2 = POWL.activity("x2", "Branch 2")
    act_3 = POWL.activity("x3", "Branch 3")

    cg_node =
      POWL.choice_graph("cg_1", [act_1, act_2, act_3], [
        {"x1", "x2"},
        {"x2", "x3"}
      ])

    nodes = %{
      "x1" => act_1,
      "x2" => act_2,
      "x3" => act_3,
      "cg_1" => cg_node
    }

    assert {:ok, model} = POWL.new(nodes, root: "cg_1")
    assert {:ok, language} = POWL.language(model)
    assert ["Branch 1"] in language
    assert ["Branch 2"] in language
    assert ["Branch 3"] in language
  end

  test "compiles POWL 2.0 model to sound 1-safe WorkflowNet" do
    act_a = POWL.activity("a", "A")
    act_b = POWL.activity("b", "B")
    act_c = POWL.activity("c", "C")
    act_d = POWL.activity("d", "D")

    choice_node = POWL.choice("ch", [act_b, act_c])

    po_node =
      POWL.partial_order("root", [act_a, choice_node, act_d], [
        {"a", "ch"},
        {"ch", "d"}
      ])

    nodes = %{
      "a" => act_a,
      "b" => act_b,
      "c" => act_c,
      "d" => act_d,
      "ch" => choice_node,
      "root" => po_node
    }

    assert {:ok, powl_model} = POWL.new(nodes, root: "root")
    assert {:ok, wf_net} = POWL.to_workflow_net(powl_model)

    assert :ok = WorkflowNet.validate_structure(wf_net)
    assert {:ok, report} = WorkflowNet.verify_soundness(wf_net)
    assert report.sound? == true
    assert report.one_safe? == true
    assert report.option_to_complete? == true
    assert report.proper_completion? == true
  end

  test "refuses cyclic POWL node" do
    act_a = POWL.activity("a", "A")
    act_b = POWL.activity("b", "B")
    po_node = POWL.partial_order("root", [act_a, act_b], [{"a", "b"}, {"b", "a"}])

    nodes = %{"a" => act_a, "b" => act_b, "root" => po_node}
    assert {:error, %Refusal{code: :cyclic_powl_node}} = POWL.new(nodes, root: "root")
  end
end
