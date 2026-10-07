# W680 — ex4pm AIRo surface pin (ledger-verification lane).
# Backlog: /Users/sac/xaas/docs/cro/artifacts/airo-wiring-ledger.md
# Drift note: the ledger's consolidated table has NO ex4pm row and its
# cross-repo sha table does not list ex4pm, yet ex4pm carries a committed
# AIRo surface: priv/ontologies/airo_risk_description.ttl
# (sha256 766059ce26259dde6806b3909ebaed231d5d6e0472ffc0d6c82e379d51e8df19,
# 7,956 B) with court test/aux
# court test/w645b_airo_risk_description_test.exs (tracked, main@46bfcc8).
# This pin asserts the real on-disk surface (not the ledger's absent row).
#
# Chicago-style: real files, real sha256, real rdflib parse. No mocks.

defmodule W680AiroSurfacePinTest do
  use ExUnit.Case, async: true

  @ttl "priv/ontologies/airo_risk_description.ttl"
  @desc_sha "766059ce26259dde6806b3909ebaed231d5d6e0472ffc0d6c82e379d51e8df19"

  # Canonical vendored AIRo 1.0 vocabulary (w600/w621b pin).
  @vocab_candidates ["/Users/sac/xaas/priv/semantic/airo/airo.ttl", "/tmp/airo.ttl"]
  @vocab_sha "6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469"

  @airo_terms ~w(
    AISystem RiskSource Hazard Risk Consequence Impact Likelihood Severity
    RiskControl AIProvider
    hasRisk isProvidedBy hasConsequence hasImpact hasLikelihood hasSeverity
    hasRiskControl mitigatesRiskConcept detectsRiskConcept hasDocumentation
  )

  defp ttl_path, do: Path.expand(@ttl, File.cwd!())
  defp vocab_path, do: Enum.find(@vocab_candidates, &File.exists?/1)

  test "AIRo description TTL exists with the pinned sha256 (byte-exact surface)" do
    path = ttl_path()
    assert File.exists?(path), "missing #{path}"

    {:ok, body} = File.read(path)
    assert :crypto.hash(:sha256, body) |> Base.encode16(case: :lower) == @desc_sha,
           "AIRo description drift vs pin #{@desc_sha}"
  end

  test "vocabulary candidate matches the w600 canonical AIRo 1.0 pin" do
    vocab = vocab_path()
    assert vocab, "no AIRo vocabulary copy found"

    {:ok, body} = File.read(vocab)
    assert :crypto.hash(:sha256, body) |> Base.encode16(case: :lower) == @vocab_sha,
           "vocabulary #{vocab} drifts from AIRo 1.0 pin"
  end

  test "TTL parses with rdflib and non-trivially extends under the AIRo vocabulary" do
    vocab = vocab_path()
    assert vocab

    {out, 0} =
      System.cmd("/tmp/airo-venv/bin/python", [
        "-c",
        """
        import sys, rdflib
        g = rdflib.Graph()
        g.parse(sys.argv[1], format="turtle")
        n0 = len(g)
        g.parse(sys.argv[2], format="turtle")
        print("%d %d" % (n0, len(g)))
        """,
        ttl_path(),
        vocab
      ])

    [desc_n, union_n] = out |> String.trim() |> String.split() |> Enum.map(&String.to_integer/1)
    assert desc_n > 0
    assert union_n > desc_n
  end

  test "all pinned AIRo terms appear in the description" do
    {:ok, desc} = File.read(ttl_path())

    for term <- @airo_terms do
      assert desc =~ "airo:#{term}", "missing airo:#{term}"
    end
  end
end
