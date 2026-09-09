defmodule Ex4pm.OCELPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Ex4pm.Core.Hash
  alias Ex4pm.EventLog
  alias Ex4pm.OCEL
  alias Ex4pm.Test.Generators

  @moduletag :property

  property "OCEL normalization is idempotent and preserves subject hash invariant" do
    check all(envelope <- Generators.batch_envelope_generator()) do
      raw_ocel = %{
        "objects" => envelope["objects"],
        "events" => envelope["events"]
      }

      assert {:ok, %EventLog{} = log1} = OCEL.normalize(raw_ocel)
      assert {:ok, %EventLog{} = log2} = OCEL.normalize(log1)

      # Idempotency
      assert log1.subject.hash == log2.subject.hash
      assert length(log1.events) == length(envelope["events"])
      assert map_size(log1.objects) == map_size(envelope["objects"])
      assert String.starts_with?(log1.subject.hash, "sha256:")

      # Verification of digest recomputation
      recomputed =
        Hash.digest(%{
          events: log1.events,
          objects: log1.objects,
          object_relationships: log1.object_relationships
        })

      assert log1.subject.hash == recomputed
    end
  end

  property "Batch envelope validation correctly accepts generated valid envelopes" do
    check all(envelope <- Generators.batch_envelope_generator()) do
      assert {:ok, validated} = OCEL.validate_envelope(envelope)
      assert validated.schema == "chatgpt-cloud-ocel/1"
      assert validated.sequence >= 1
      assert is_list(validated.events)
    end
  end
end
