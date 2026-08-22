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

  test "evaluates cross-step cumulative attribute diff guard across multiple events" do
    # DAPN: p_in -> [AuthorizeOrder] -> p_auth -> [CapturePayment (if auth - fee >= 90)] -> p_out
    dapn = %{
      transitions: %{
        auth: %{
          inputs: ["p_in"],
          outputs: ["p_auth"],
          label: "AuthorizeOrder",
          guard: :always_true
        },
        capture: %{
          inputs: ["p_auth"],
          outputs: ["p_out"],
          label: "CapturePayment",
          guard: {:diff, :authorized_amount, :processing_fee, :gte, 90}
        }
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    # Step 1 sets authorized_amount = 100
    # Step 2 sets processing_fee = 5 -> diff is 95 (>= 90, satisfies!)
    trace = [
      %{activity: "AuthorizeOrder", attributes: %{"authorized_amount" => 100}},
      %{activity: "CapturePayment", attributes: %{"processing_fee" => 5}}
    ]

    assert {:ok, result} = DAPN.execute_dapn_trace(trace, dapn)
    assert result.satisfied? == true
    assert result.final_env["authorized_amount"] == 100
    assert result.final_env["processing_fee"] == 5
  end
end
