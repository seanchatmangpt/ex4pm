defmodule Ex4pm.EngineFerroplanSessionOpsTest do
  @moduledoc """
  Real-wasm coverage for the ferroplan `session_*` ABI ops that
  `test/engine_ferroplan_session_test.exs` does not drive: goal and restriction
  setters, plan cursor ops, belief/fluent ops, temporal ops and the memory
  probes. Every case boots a real session over the bundled `ferroplan_wasm.wasm`
  (logistics fixture) through `Ex4pm.Engine.Ferroplan.Sessions` and asserts on
  the state the guest reports back -- no doubles.
  """
  use ExUnit.Case, async: false

  alias Ex4pm.Engine.Ferroplan.Sessions

  @artifact Path.expand("../priv/ferroplan/ferroplan_wasm.wasm", __DIR__)
  @fixtures Path.expand("support/fixtures/ferroplan", __DIR__)
  @goal "(>= (stock b box) 1)"

  defp fixture(name), do: File.read!(Path.join(@fixtures, name))

  defp opts do
    digest = :crypto.hash(:sha256, File.read!(@artifact)) |> Base.encode16(case: :lower)
    [ferroplan_artifact: @artifact, ferroplan_expected_sha256: digest]
  end

  defp logistics do
    {:ok, id} =
      Sessions.new(fixture("logistics_domain.pddl"), fixture("logistics_p1.pddl"), opts())

    on_exit(fn -> Sessions.free(id) end)
    id
  end

  defp actions(steps), do: Enum.map(steps, & &1["action"])

  test "set_goal + set_fluent + goal_met: the goal holds exactly when the fluent says so" do
    id = logistics()

    assert {:ok, %{"ok" => true}} = Sessions.call(id, :set_goal, %{goal: @goal})
    assert {:ok, %{"goal_met" => false}} = Sessions.call(id, :goal_met)

    assert {:ok, %{"ok" => true}} =
             Sessions.call(id, :set_fluent, %{name: "(stock b box)", value: 1.0})

    assert {:ok, %{"value" => 1.0}} = Sessions.call(id, :fluent, %{name: "(stock b box)"})
    assert {:ok, %{"goal_met" => true}} = Sessions.call(id, :goal_met)

    assert {:ok, %{"ok" => true}} =
             Sessions.call(id, :set_fluent, %{name: "(stock b box)", value: 0.0})

    assert {:ok, %{"value" => +0.0}} = Sessions.call(id, :fluent, %{name: "(stock b box)"})
    assert {:ok, %{"goal_met" => false}} = Sessions.goal_met?(id)
  end

  test "set_goal with unparsable goal is a typed engine refusal" do
    id = logistics()

    assert {:error, %Ex4pm.Refusal{code: :ferroplan_engine_error}} =
             Sessions.call(id, :set_goal, %{goal: "not a goal"})
  end

  test "plan cursor: think stashes a plan, step/advance walk it, drop_plan clears it" do
    id = logistics()
    assert {:ok, %{"solved" => true, "plan" => %{"steps" => steps}}} = Sessions.think(id)
    assert actions(steps) == ["LOAD-PKG", "DRIVE", "UNLOAD-PKG"]

    assert {:ok, %{"action" => "LOAD-PKG", "index" => 0}} = Sessions.call(id, :step)
    assert {:ok, %{"ok" => true}} = Sessions.call(id, :advance)
    assert {:ok, %{"action" => "DRIVE", "index" => 1}} = Sessions.call(id, :step)

    assert {:ok, %{"value" => [%{"action" => "DRIVE"}, %{"action" => "UNLOAD-PKG"}]}} =
             Sessions.suffix(id)

    assert {:ok, %{"ok" => true}} = Sessions.call(id, :drop_plan)
    assert {:ok, %{"has_plan" => false}} = Sessions.call(id, :has_plan)
    assert {:ok, %{"value" => nil}} = Sessions.call(id, :step)
  end

  test "plan_valid judges an explicit plan from a cursor; a truncated bogus plan is invalid" do
    id = logistics()
    assert {:ok, %{"plan" => plan}} = Sessions.think(id)

    assert {:ok, %{"valid" => true}} = Sessions.call(id, :plan_valid, %{from: 0, plan: plan})

    # dropping the drive leaves the truck at a, so the unload at b is impossible
    broken = %{plan | "steps" => Enum.reject(plan["steps"], &(&1["action"] == "DRIVE"))}

    assert {:ok, %{"valid" => false}} =
             Sessions.call(id, :plan_valid, %{from: 0, plan: broken})
  end

  test "set_fact / fact / set_timed_fact + elapse: a timed belief change lands after dt" do
    id = logistics()

    assert {:ok, %{"value" => true}} = Sessions.call(id, :fact, %{name: "(at-veh t1 a)"})

    assert {:ok, %{"ok" => true}} =
             Sessions.call(id, :set_fact, %{name: "(at-veh t1 b)", value: true})

    assert {:ok, %{"value" => true}} = Sessions.call(id, :fact, %{name: "(at-veh t1 b)"})

    assert {:ok, %{"ok" => true}} =
             Sessions.call(id, :set_timed_fact, %{name: "(at-veh t1 a)", dt: 1.5, value: false})

    # not yet: the change is scheduled 1.5 time units out
    assert {:ok, %{"value" => true}} = Sessions.call(id, :fact, %{name: "(at-veh t1 a)"})
    assert {:ok, %{"value" => events}} = Sessions.call(id, :elapse, %{dt: 2.0})
    assert is_list(events)
    assert {:ok, %{"value" => false}} = Sessions.call(id, :fact, %{name: "(at-veh t1 a)"})
  end

  test "apply_start begins a durative action; elapse completes it" do
    id = logistics()

    assert {:ok, %{"ok" => true}} = Sessions.call(id, :apply_start, %{name: "(drive t1 a b)"})
    # start effect: the truck has left a, has not arrived at b yet
    assert {:ok, %{"value" => false}} = Sessions.call(id, :fact, %{name: "(at-veh t1 a)"})
    assert {:ok, %{"value" => false}} = Sessions.call(id, :fact, %{name: "(at-veh t1 b)"})

    assert {:ok, %{"value" => []}} = Sessions.call(id, :elapse, %{dt: 2.0})
    assert {:ok, %{"value" => false}} = Sessions.call(id, :fact, %{name: "(at-veh t1 b)"})

    assert {:ok, %{"value" => _}} = Sessions.call(id, :elapse, %{dt: 2.0})
    assert {:ok, %{"value" => true}} = Sessions.call(id, :fact, %{name: "(at-veh t1 b)"})
  end

  test "restrict_contains / restrict_prefix_claims shrink the action space and change think" do
    free = logistics()
    assert {:ok, %{"solved" => true}} = Sessions.think(free)

    only_loads = logistics()

    assert {:ok, %{"ok" => true}} =
             Sessions.call(only_loads, :restrict_contains, %{filter: "load"})

    assert {:ok, %{"solved" => false}} = Sessions.think(only_loads)

    no_truck_drive = logistics()

    assert {:ok, %{"ok" => true}} =
             Sessions.call(no_truck_drive, :restrict_prefix_claims, %{
               prefix: "(drive",
               claimed: "t1"
             })

    assert {:ok, %{"solved" => false}} = Sessions.think(no_truck_drive)
  end

  test "world_bytes / mind_bytes report the guest's live memory footprint" do
    id = logistics()
    assert {:ok, %{"bytes" => world}} = Sessions.call(id, :world_bytes)
    assert {:ok, %{"bytes" => mind}} = Sessions.call(id, :mind_bytes)
    assert is_integer(world) and world > 0
    assert is_integer(mind) and mind > 0

    assert {:ok, %{"solved" => true}} = Sessions.think(id)
    assert {:ok, %{"bytes" => mind_after}} = Sessions.call(id, :mind_bytes)
    assert mind_after >= mind
  end
end
