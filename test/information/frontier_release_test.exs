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

  defp binding do
    %{
      subject_identity: "repo@0123456789abcdef",
      verifier_identity: "verifier:v1"
    }
  end

  defp evidence(claim_id, overrides \\ %{}) do
    Map.merge(
      %{
        claim_id: claim_id,
        subject_identity: binding().subject_identity,
        verifier_identity: binding().verifier_identity,
        evidence_ref: "receipt:#{claim_id}",
        replay_ref: "replay:#{claim_id}",
        standing: "ALIVE"
      },
      overrides
    )
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

  test "opportunity refuses an observation that has not crossed the observation admission fence" do
    assert {:error, {:refused, :unadmitted_source_observation, _}} =
             FrontierRelease.qualify_opportunity(observation_attrs(), %{
               response_mode: :compose,
               target_repository: "seanchatmangpt/xaas",
               required_capability: "x",
               benchmark: benchmark()
             })
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

  test "mixed earned and withheld claims are PARTIAL_ALIVE with no publication authority" do
    claims = [
      %{id: "c1", text: "Capability X executed"},
      %{id: "c2", text: "Capability Y executed"}
    ]

    assert {:ok, release} = FrontierRelease.qualify_release(claims, [evidence("c1")], binding())
    assert Enum.map(release.earned_claims, & &1.id) == ["c1"]
    assert release.withheld_claim_ids == ["c2"]
    assert release.standing == :partial_alive
    assert release.admitted_subject_identity == binding().subject_identity
    assert release.admitted_verifier_identity == binding().verifier_identity
    assert release.publication_authority == :none
  end

  test "all admitted claims must be earned before release standing is ALIVE" do
    claims = [
      %{id: "c1", text: "Capability X executed"},
      %{id: "c2", text: "Capability Y executed"}
    ]

    assert {:ok, release} =
             FrontierRelease.qualify_release(claims, [evidence("c1"), evidence("c2")], binding())

    assert Enum.map(release.earned_claims, & &1.id) == ["c1", "c2"]
    assert release.withheld_claim_ids == []
    assert release.standing == :alive
    assert release.publication_authority == :none
  end

  test "wrong subject identity cannot promote an otherwise ALIVE receipt" do
    claims = [%{id: "c1", text: "Capability X executed"}]
    wrong_subject = evidence("c1", %{subject_identity: "repo@wrong"})

    assert {:ok, release} = FrontierRelease.qualify_release(claims, [wrong_subject], binding())
    assert release.earned_claims == []
    assert release.withheld_claim_ids == ["c1"]
    assert release.standing == :blocked
  end

  test "wrong verifier identity cannot promote an otherwise ALIVE receipt" do
    claims = [%{id: "c1", text: "Capability X executed"}]
    wrong_verifier = evidence("c1", %{verifier_identity: "verifier:unadmitted"})

    assert {:ok, release} = FrontierRelease.qualify_release(claims, [wrong_verifier], binding())
    assert release.earned_claims == []
    assert release.withheld_claim_ids == ["c1"]
    assert release.standing == :blocked
  end

  test "non-ALIVE evidence never promotes a claim" do
    claims = [%{id: "c1", text: "Capability X executed"}]

    assert {:ok, release} =
             FrontierRelease.qualify_release(
               claims,
               [evidence("c1", %{standing: "PARTIAL_ALIVE"})],
               binding()
             )

    assert release.earned_claims == []
    assert release.withheld_claim_ids == ["c1"]
    assert release.standing == :blocked
  end

  test "existential evidence selection is order independent" do
    claims = [%{id: "c1", text: "Capability X executed"}]
    alive = evidence("c1")
    partial = evidence("c1", %{standing: "PARTIAL_ALIVE", evidence_ref: "receipt:partial"})

    for receipts <- [[alive, partial], [partial, alive]] do
      assert {:ok, release} = FrontierRelease.qualify_release(claims, receipts, binding())
      assert Enum.map(release.earned_claims, & &1.id) == ["c1"]
      assert release.withheld_claim_ids == []
      assert release.standing == :alive
      assert hd(release.earned_claims).evidence.standing == :alive
    end
  end

  test "unknown evidence standing is refused rather than silently lowered" do
    claims = [%{id: "c1", text: "Capability X executed"}]

    assert {:error, {:refused, :unknown_evidence_standing, _}} =
             FrontierRelease.qualify_release(
               claims,
               [evidence("c1", %{standing: "MAGIC"})],
               binding()
             )
  end

  test "incomplete evidence is refused instead of being silently ignored" do
    claims = [%{id: "c1", text: "Capability X executed"}]
    incomplete = [%{claim_id: "c1", standing: "ALIVE"}]

    assert {:error, {:refused, :missing_or_invalid_field, _}} =
             FrontierRelease.qualify_release(claims, incomplete, binding())
  end

  test "release qualification without exact binding is refused" do
    claims = [%{id: "c1", text: "Capability X executed"}]

    assert {:error, {:refused, :missing_release_binding, _}} =
             FrontierRelease.qualify_release(claims, [evidence("c1")])
  end

  test "duplicate working claim identity is refused" do
    claims = [
      %{id: "c1", text: "Capability X executed"},
      %{id: "c1", text: "Conflicting duplicate identity"}
    ]

    assert {:error, {:refused, :duplicate_working_claim_id, _}} =
             FrontierRelease.qualify_release(claims, [evidence("c1")], binding())
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
