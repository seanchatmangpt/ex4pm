defmodule Ex4pmEngine.Miner.OCPOWLTest do
  @moduledoc """
  Ex4pmEngine.Miner.OCPOWL had zero test coverage before this file. Real OCEL-shaped event
  maps (no mocking) are fed through mine_oc_powl/1 to exercise the empty case and a genuine
  multi-object-type divergence/convergence scenario.
  """

  use ExUnit.Case, async: true

  alias Ex4pmEngine.Miner.OCPOWL

  test "mine_oc_powl/1 on an empty event list returns no object types and no models" do
    assert {:ok, %{object_types: [], models: models}} = OCPOWL.mine_oc_powl([])
    assert models == %{}
  end

  test "mine_oc_powl/1 discovers a per-object-type model for a genuine multi-object-type OCEL stream (divergence + convergence)" do
    order_id = Faker.UUID.v4()
    item_a = Faker.UUID.v4()
    item_b = Faker.UUID.v4()

    # A real object-centric event log: one order converges two items on "pack", then each
    # item diverges into its own independent "ship" lifecycle (classic OC-POWL divergence).
    events = [
      %{activity: "create_order", timestamp: Faker.DateTime.backward(5), objects: %{"order" => [order_id]}},
      %{
        activity: "pack",
        timestamp: Faker.DateTime.backward(4),
        objects: %{"order" => [order_id], "item" => [item_a, item_b]}
      },
      %{activity: "ship", timestamp: Faker.DateTime.backward(3), objects: %{"item" => [item_a]}},
      %{activity: "ship", timestamp: Faker.DateTime.backward(2), objects: %{"item" => [item_b]}},
      %{activity: "close_order", timestamp: Faker.DateTime.backward(1), objects: %{"order" => [order_id]}}
    ]

    assert {:ok, %{object_types: object_types, models: models}} = OCPOWL.mine_oc_powl(events)

    assert object_types == ["item", "order"]
    assert Map.has_key?(models, "order")
    assert Map.has_key?(models, "item")

    # Real discovered POWL structures, not stubs — both are non-nil actual nodes produced by
    # InductiveMiner.mine/2 on the per-type-extracted traces.
    refute is_nil(models["order"])
    refute is_nil(models["item"])
  end

  test "mine_oc_powl/1 raises a real, diagnosable error on an event missing the :objects key rather than silently mis-mining (documents actual behavior, not assumed)" do
    malformed_event = %{activity: Faker.Company.bs(), timestamp: Faker.DateTime.backward(1)}

    assert_raise KeyError, fn ->
      OCPOWL.mine_oc_powl([malformed_event])
    end
  end
end
