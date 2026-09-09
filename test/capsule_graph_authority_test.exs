defmodule Ex4pmCore.CapsuleGraph.AuthorityTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.Authority

  test "observe select construct verify admit while DO requires BRCE" do
    for action <- [:observe, :select, :construct, :verify] do
      assert {:ok, ^action} = Authority.admit(action)
    end

    assert {:error, {:refused, :brce_required_for_do}} = Authority.admit(:do)
    assert {:error, {:refused, :unknown_capsule_action, :deploy}} = Authority.admit(:deploy)
  end
end
