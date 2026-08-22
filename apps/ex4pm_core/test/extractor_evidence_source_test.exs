defmodule Ex4pmCore.ExtractorEvidenceSourceTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.Source

  test "equivalent map source identity hashes deterministically" do
    assert {:ok, left} = Source.new(:ash, %{b: 2, a: 1})
    assert {:ok, right} = Source.new(:ash, %{a: 1, b: 2})
    assert left.digest == right.digest
  end
end
