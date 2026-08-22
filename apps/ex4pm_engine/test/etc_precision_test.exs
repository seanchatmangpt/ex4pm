defmodule Ex4pm.Engine.ETCPrecisionTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.ETCPrecision

  test "measures high precision on tight models and lower precision on over-generalizing models" do
    # Tight Sequence Net: A -> B -> C
    tight_net = %{
      transitions: %{
        t_a: %{inputs: ["p_in"], outputs: ["p_1"], label: "A"},
        t_b: %{inputs: ["p_1"], outputs: ["p_2"], label: "B"},
        t_c: %{inputs: ["p_2"], outputs: ["p_out"], label: "C"}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    traces = [
      ["A", "B", "C"],
      ["A", "B", "C"],
      ["A", "B", "C"]
    ]

    report_tight = ETCPrecision.calculate_precision(traces, tight_net)
    assert report_tight.precision == 1.0
    assert report_tight.total_escaping_actions == 0

    # Over-generalizing model with unused branch D: A -> (B OR D) -> C
    flower_net = %{
      transitions: %{
        t_a: %{inputs: ["p_in"], outputs: ["p_1"], label: "A"},
        t_b: %{inputs: ["p_1"], outputs: ["p_2"], label: "B"},
        t_d: %{inputs: ["p_1"], outputs: ["p_2"], label: "D"},
        t_c: %{inputs: ["p_2"], outputs: ["p_out"], label: "C"}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    # In these traces, branch D is NEVER observed!
    report_flower = ETCPrecision.calculate_precision(traces, flower_net)
    assert report_flower.precision < 1.0
    assert report_flower.total_escaping_actions > 0
  end
end
