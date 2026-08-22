defmodule Ex4pmCore.ExtractorEvidenceDigestTest do
  use ExUnit.Case, async: true

  alias Ex4pmCore.ProcessIR.Extractor.Evidence.Digest

  test "canonical evidence digest is stable across map insertion order" do
    assert Digest.of(%{b: 2, a: %{d: 4, c: 3}}) == Digest.of(%{a: %{c: 3, d: 4}, b: 2})
  end
end
