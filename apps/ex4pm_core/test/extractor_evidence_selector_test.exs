defmodule Ex4pmCore.ExtractorEvidenceSelectorTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.Selector

  test "selects strongest evidence while preserving every viable name" do
    candidates = [
      %{name: :reactor, standing: :partial_alive},
      %{name: :ash, standing: :alive},
      %{name: :ash_state_machine, standing: :partial_alive}
    ]

    assert {:ok, %{name: :ash}, [:ash, :ash_state_machine, :reactor]} = Selector.select(candidates)
  end

  test "refuses graph with no viable edge" do
    assert {:error, {:refused, :no_viable_extractor}} = Selector.select([%{name: :ash, standing: :unsupported}])
  end
end
