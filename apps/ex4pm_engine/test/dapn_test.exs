defmodule Ex4pm.Engine.DapnTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.DAPN

  test "executes data-aware trace satisfying amount threshold guard" do
    # DAPN: p_in -> [Submit] -> p_review -> [ManagerApproval (if amount > 1000)] -> p_out
    dapn = %{
      transitions: %{
        submit: %{inputs: ["p_in"], outputs: ["p_review"], label: "Submit", guard: :always_true},
        manager_app: %{
          inputs: ["p_review"],
          outputs: ["p_out"],
          label: "ManagerApproval",
          guard: {:attr, :amount, :gt, 1000}
        }
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    # Trace with amount = 5000 (satisfies guard)
    valid_trace = [
      %{activity: "Submit", attributes: %{"amount" => 5000}},
      %{activity: "ManagerApproval", attributes: %{"amount" => 5000}}
    ]

    assert {:ok, result} = DAPN.execute_dapn_trace(valid_trace, dapn)
    assert result.satisfied? == true
    assert length(result.fired_transitions) == 2

    # Trace with amount = 200 (violates guard!)
    invalid_trace = [
      %{activity: "Submit", attributes: %{"amount" => 200}},
      %{activity: "ManagerApproval", attributes: %{"amount" => 200}}
    ]

    assert {:error, {:guard_or_control_violation, "ManagerApproval", _marking, _attrs}} =
             DAPN.execute_dapn_trace(invalid_trace, dapn)
  end
end
