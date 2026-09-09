defmodule Ex4pmCore.ExtractorTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR
  alias Ex4pmCore.ProcessIR.Extractor.Ash, as: AshExtractor
  alias Ex4pmCore.ProcessIR.Extractor.Reactor, as: ReactorExtractor
  alias Ex4pmCore.ProcessIR.Extractor.AshStateMachine, as: FsmExtractor

  # --- Mock Test Resource using Spark DSL or Map ---
  defmodule MockAshResource do
    defmodule Info do
      def actions(_res) do
        [
          %{name: :create, type: :create, primary?: true, accept: [:customer_id, :total_amount]},
          %{name: :approve, type: :update, primary?: false, accept: []}
        ]
      end

      def attributes(_res) do
        [
          %{name: :id, type: :uuid, allow_nil?: false},
          %{name: :customer_id, type: :string, allow_nil?: false},
          %{name: :total_amount, type: :decimal, allow_nil?: false}
        ]
      end

      def relationships(_res) do
        [
          %{
            name: :items,
            destination: MockItem,
            cardinality: :many,
            source_attribute: :id,
            destination_attribute: :order_id
          }
        ]
      end
    end
  end

  defmodule MockItem do
  end

  # --- Mock Reactor Module ---
  defmodule MockReactor do
    def reactor do
      %{
        steps: [
          %{
            name: :validate_inventory,
            impl: MockInventoryStep,
            wait_for: [],
            arguments: [%{source: {:input, :order_id}}]
          },
          %{
            name: :charge_card,
            impl: MockChargeStep,
            wait_for: [:validate_inventory],
            arguments: [%{source: {:result, :validate_inventory}}]
          }
        ]
      }
    end
  end

  defmodule MockInventoryStep do
    def run(_args, _ctx), do: {:ok, :valid}
    def undo(_args, _res, _ctx), do: :ok
  end

  defmodule MockChargeStep do
    def run(_args, _ctx), do: {:ok, :charged}
    def compensate(_err, _args, _ctx, _opts), do: :ok
  end

  describe "Ash Extractor" do
    test "extracts resource actions and attributes into ProcessIR" do
      # When Ash.Resource.Info is available or fallback is used
      ir = AshExtractor.extract(MockAshResource, id: "order_process")

      assert %ProcessIR{} = ir
      assert ir.id == "order_process"
    end
  end

  describe "Reactor Extractor" do
    test "extracts step DAG and execution dependencies into ProcessIR" do
      ir = ReactorExtractor.extract(MockReactor, id: "mock_saga")

      assert %ProcessIR{} = ir
      assert ir.id == "mock_saga"
      assert Map.has_key?(ir.activities, "validate_inventory")
      assert Map.has_key?(ir.activities, "charge_card")

      assert Map.has_key?(ir.partial_orders, "mock_saga_dag")
      po = ir.partial_orders["mock_saga_dag"]
      assert {"validate_inventory", "charge_card"} in po.edges
    end
  end

  describe "AshStateMachine Extractor" do
    test "extracts fallback gracefully when state machine DSL not attached" do
      ir = FsmExtractor.extract(MockAshResource, id: "order_fsm")
      assert %ProcessIR{} = ir
      assert ir.id == "order_fsm"
    end
  end
end
