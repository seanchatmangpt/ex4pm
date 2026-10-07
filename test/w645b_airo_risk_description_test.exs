# W645b — ex4pm AIRo risk description court.
# Subject: priv/ontologies/airo_risk_description.ttl
# Vocabulary: AIRo 1.0 (sha256 6274d2d8711e… per W600 vendor receipt), from
# /Users/sac/xaas/priv/semantic/airo/airo.ttl (canonical vendored copy) with a
# /tmp/airo.ttl fallback.
#
# Chicago-style: real files on disk, real rdflib parse, real canary execution.

defmodule W645bAiroRiskDescriptionTest do
  use ExUnit.Case, async: true

  @ttl "priv/ontologies/airo_risk_description.ttl"
  @vocab_candidates ["/Users/sac/xaas/priv/semantic/airo/airo.ttl", "/tmp/airo.ttl"]

  @airo_terms ~w(
    AISystem RiskSource Hazard Risk Consequence Impact Likelihood Severity
    RiskControl AIProvider
    hasRisk isProvidedBy hasConsequence hasImpact hasLikelihood hasSeverity
    hasRiskControl mitigatesRiskConcept detectsRiskConcept hasDocumentation
  )

  defp ttl_path, do: Path.expand(@ttl, File.cwd!())
  defp vocab_path, do: Enum.find(@vocab_candidates, &File.exists?/1)

  test "AIRo description TTL exists on disk" do
    assert File.exists?(ttl_path()), "missing #{ttl_path()}"
  end

  test "TTL parses structurally with rdflib and union with the AIRo vocabulary" do
    vocab = vocab_path()
    assert vocab, "no AIRo vocabulary copy found"

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

  test "every cited local path exists on disk (line-number suffixes not used)" do
    {:ok, body} = File.read(ttl_path())

    paths =
      Regex.scan(~r/hasDocumentation "([^"]+)"/, body)
      |> Enum.map(&List.last/1)
      |> Enum.uniq()

    assert length(paths) >= 4

    for p <- paths do
      assert File.exists?(Path.expand(p, File.cwd!())), "cited path missing: #{p}"
    end
  end

  test "every AIRo term used is defined in the vocabulary" do
    {:ok, desc} = File.read(ttl_path())
    {:ok, vocab} = File.read(vocab_path())

    for term <- @airo_terms do
      assert desc =~ "airo:#{term}", "description uses undefined term airo:#{term}"
      assert vocab =~ term, "term #{term} not in AIRo vocabulary"
    end
  end

  @tag :w645b
  test "OS-20 canary still passes: Map.update/4 skips fun on absent key on this runtime" do
    assert Map.update(%{}, :k, 7, &(&1 + 1)) == %{k: 7}
  end
end
