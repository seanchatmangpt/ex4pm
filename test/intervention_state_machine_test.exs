defmodule Ex4pm.Domain.InterventionStateMachineTest do
  @moduledoc """
  Real, no-mock exercise of the AshStateMachine-backed lifecycle on
  `Ex4pm.Domain.Intervention`: real `Ash.create!/2` and `Ash.update!/2`
  against the real ETS data layer, asserting on the real persisted
  `:status` field -- no interaction-based mocking of Ash or the state
  machine extension.
  """

  use ExUnit.Case, async: true

  alias Ex4pm.Domain.Intervention

  describe "real lifecycle transitions on the ETS-backed resource" do
    test "creates in the real :proposed initial state" do
      intervention =
        Intervention
        |> Ash.Changeset.for_create(:create, %{
          subject_hash: "sha256:subject-1",
          kind: :capability_grant,
          authority_ref: "authority:construct-1"
        })
        |> Ash.create!()

      assert intervention.status == :proposed
    end

    test "a real legal transition (:admit) really updates the real :status field" do
      intervention =
        Intervention
        |> Ash.Changeset.for_create(:create, %{
          subject_hash: "sha256:subject-2",
          kind: :capability_grant,
          authority_ref: "authority:construct-2"
        })
        |> Ash.create!()

      assert intervention.status == :proposed

      admitted =
        intervention
        |> Ash.Changeset.for_update(:admit, %{authority_ref: "authority:construct-2-admitted"})
        |> Ash.update!()

      assert admitted.status == :admitted
      assert admitted.authority_ref == "authority:construct-2-admitted"

      actuated =
        admitted
        |> Ash.Changeset.for_update(:actuate, %{receipt_hash: "sha256:receipt-actuate"})
        |> Ash.update!()

      assert actuated.status == :actuated
      assert actuated.receipt_hash == "sha256:receipt-actuate"

      verified =
        actuated
        |> Ash.Changeset.for_update(:verify, %{receipt_hash: "sha256:receipt-verify"})
        |> Ash.update!()

      assert verified.status == :verified
      assert verified.receipt_hash == "sha256:receipt-verify"
    end

    test "a real legal :refuse transition from :proposed reaches the terminal :refused state" do
      intervention =
        Intervention
        |> Ash.Changeset.for_create(:create, %{
          subject_hash: "sha256:subject-3",
          kind: :capability_grant
        })
        |> Ash.create!()

      refused =
        intervention
        |> Ash.Changeset.for_update(:refuse, %{payload: %{"reason" => "policy_violation"}})
        |> Ash.update!()

      assert refused.status == :refused
      assert refused.payload == %{"reason" => "policy_violation"}
    end

    test "a real illegal transition (:verify from :proposed) is really rejected" do
      intervention =
        Intervention
        |> Ash.Changeset.for_create(:create, %{
          subject_hash: "sha256:subject-4",
          kind: :capability_grant
        })
        |> Ash.create!()

      assert intervention.status == :proposed

      assert_raise Ash.Error.Invalid, fn ->
        intervention
        |> Ash.Changeset.for_update(:verify, %{receipt_hash: "sha256:should-not-apply"})
        |> Ash.update!()
      end
    end

    test "a real illegal transition (:admit after already :refused) is really rejected" do
      intervention =
        Intervention
        |> Ash.Changeset.for_create(:create, %{
          subject_hash: "sha256:subject-5",
          kind: :capability_grant
        })
        |> Ash.create!()

      refused =
        intervention
        |> Ash.Changeset.for_update(:refuse, %{})
        |> Ash.update!()

      assert refused.status == :refused

      assert_raise Ash.Error.Invalid, fn ->
        refused
        |> Ash.Changeset.for_update(:admit, %{authority_ref: "authority:should-not-apply"})
        |> Ash.update!()
      end
    end
  end
end
