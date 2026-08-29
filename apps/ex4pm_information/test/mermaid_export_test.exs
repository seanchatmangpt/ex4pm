defmodule Ex4pm.Information.MermaidExportTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Information.MermaidExport

  test "renders the real Ex4pm.Information.Flow reactor as a mermaid flowchart binary" do
    diagram = MermaidExport.to_mermaid!(Ex4pm.Information.Flow)

    assert is_binary(diagram)
    assert diagram =~ "flowchart"
    assert diagram =~ "normalize"
    assert diagram =~ "admit"
    assert diagram =~ "execute"
  end

  test "accepts pass-through Reactor.Mermaid options (top_to_bottom direction)" do
    diagram = MermaidExport.to_mermaid!(Ex4pm.Information.Flow, direction: :top_to_bottom)

    assert is_binary(diagram)
    assert diagram =~ "flowchart TB"
  end
end
