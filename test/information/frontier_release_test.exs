defmodule Ex4pm.Information.FrontierReleaseTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Information.FrontierRelease

  defp observation_attrs do
    %{
      source_url: "https://example.test/frontier-release",
      publisher: "Example Lab",
      published_at: "2026-09-09T12:00:00Z",
      content_digest: "blake3:source",
      claims: ["Demonstrated capability X", "Reported benchmark Y"]
    }
  end

  defp benchmark do
    %{
      id: "benchmark:frontier-x",
      metric: "verified-capability-per-semantic-recomputation",
      acceptance_predicate: "exact-subject verifier passes",
      falsifier: "claim cannot be independently replayed"
    }
  end

  test "source release normalizes as observation without authority" do
    assert {:ok, observed} = FrontierRelease.normalize_observation(observation_attrs())
    assert observed.standing == :observed
    assert observed.authority == :none
    assert observed.content_digest == "blake3:source"
  end

  test "malformed source timestamp is a typed refusal" do
    attrs = Map.put(observation_attrs(), :published_at, "not-a-time")

    assert {:error, {:refused, :invalid_published_at, _}} =
             FrontierRelease.normalize_observation(attrs)
  end

  test "bounded opportunity is SELECT-only candidate" do
    assert {:ok, observed} = FrontierRelease.normalize_observation(observation_attrs())

    assert {:ok, opportunity} =
             FrontierRelease.qualify_opportunity(observed, %{
               response_mode: :compose,
               target_repository: "seanchatmangpt/xaas",
               required_capability: "frontier release product surface",
               benchmark: benchmark()
             })

    assert opportunity.standing == :candidate
    assert opportunity.authority == :select_only
    assert opportunity.response_mode == :compose
    assert opportunity.benchmark.id == "benchmark:frontier-x"
  end

  test "unknown response mode is refused rather than invented" do
    assert {:ok, observed} = FrontierRelease.normalize_observation(observation_attrs())

    assert {:error, {:refused, :unknown_response_mode, _}} =
             FrontierRelease.qualify_opportunity(observed, %{
               response_mode: "magic",
               target_repository: "seanchatmangpt/xaas",
               required_capability: "x",
               benchmark: benchmark()
             })
  end

  test "earned release is the evidence-backed subset of working-backwards claims" do
    claims = [
      %{id: "c1", text: "Capability X executed"},
      %{id: "c2", text: "Capability Y executed"}
    ]

    evidence = [
      %{
        claim_id: "c1",
        subject_identity: "repo@0123456789abcdef",
        verifier_identity: "verifier:v1",
        evidence_ref: "receipt:1",
        replay_ref: "replay:1",
        standing: "ALIVE"
      }
    ]

    assert {:ok, release} = FrontierRelease.qualify_release(claims, evidence)
    assert Enum.map(release.earned_claims, & &1.id) == ["c1"]
    assert release.withheld_claim_ids == ["c2"]
    assert release.standing == :alive
    assert release.publication_authority == :none
  end

  test "non-ALIVE evidence never promotes a claim" do
    claims = [%{id: "c1", text: "Capability X executed"}]

    evidence = [
      %{
        claim_id: "c1",
        subject_identity: "repo@0123456789abcdef",
        verifier_identity: "verifier:v1",
        evidence_ref: "receipt:1",
        replay_ref: "replay:1",
        standing: "PARTIAL_ALIVE"
      }
    ]

    assert {:ok, release} = FrontierRelease.qualify_release(claims, evidence)
    assert release.earned_claims == []
    assert release.withheld_claim_ids == ["c1"]
    assert release.standing == :blocked
  end

  test "incomplete evidence is refused instead of being silently ignored" do
    claims = [%{id: "c1", text: "Capability X executed"}]
    evidence = [%{claim_id: "c1", standing: "ALIVE"}]

    assert {:error, {:refused, :missing_or_invalid_field, _}} =
             FrontierRelease.qualify_release(claims, evidence)
  end

  test "forward lifecycle trace conforms" do
    assert {:ok, :conformant} =
             FrontierRelease.conform_trace([
               :observe,
               :extract,
               :fence,
               :invert,
               :specify,
               :manufacture,
               :verify,
               :publish
             ])
  end

  test "lifecycle regression is refused" do
    assert {:error, {:refused, :stage_regression, _}} =
             FrontierRelease.conform_trace([:observe, :specify, :extract])
  end
end
