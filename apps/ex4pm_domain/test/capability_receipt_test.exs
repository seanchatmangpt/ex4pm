defmodule Ex4pmDomain.CapabilityReceiptTest do
  use ExUnit.Case, async: false

  alias Ex4pmDomain.CapabilityReceipt

  describe "CapabilityReceipt Ash Resource" do
    test "creates and retrieves an autonomic capability liveness receipt" do
      params = %{
        capability: "powl_soundness_verification",
        subject: "https://enterprise.fortune5.com/system/ex4pm",
        status: :alive,
        exit_code: 0,
        standing: :ALIVE,
        agent_id: "agent_42",
        run_id: "run_999",
        digest: "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      }

      assert {:ok, receipt} =
               CapabilityReceipt
               |> Ash.Changeset.for_create(:create, params)
               |> Ash.create()

      assert receipt.capability == "powl_soundness_verification"
      assert receipt.standing == :ALIVE
      assert receipt.exit_code == 0
    end
  end
end
