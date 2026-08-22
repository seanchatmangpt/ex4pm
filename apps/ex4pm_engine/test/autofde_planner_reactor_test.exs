defmodule Ex4pmEngine.AutoFdePlannerReactorTest do
  use ExUnit.Case, async: false

  alias Ex4pmEngine.Reactors.AutoFdePlannerReactor
  alias Ex4pmCore.ProcessIR.Extractor.Reactor, as: ReactorExtractor

  describe "AutoFDE Reference Planner Reactor" do
    test "can be introspected into a ProcessIR partial order DAG" do
      ir = ReactorExtractor.extract(AutoFdePlannerReactor, id: "autofde_planner")

      assert ir.id == "autofde_planner"
      assert Map.has_key?(ir.activities, "primary_plan")
      assert Map.has_key?(ir.activities, "fallback_plan")
      assert Map.has_key?(ir.activities, "final")
      assert Map.has_key?(ir.partial_orders, "autofde_planner_dag")
    end
  end
end
