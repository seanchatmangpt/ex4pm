defmodule Ex4pm.Test.Generators do
  @moduledoc """
  Shared StreamData generators for OCEL 2.0, POWL 2.0, and Process Intelligence streams.
  Provides parity with generators in ash_r2rml and xaas.
  """

  use ExUnitProperties

  def activity_name do
    StreamData.member_of([
      "admit",
      "construct",
      "verify",
      "brce",
      "do",
      "receipt",
      "replay",
      "standing",
      "github.fetch",
      "github.commit",
      "github.pr_create",
      "ci.build",
      "ci.test",
      "ash.action",
      "reactor.step"
    ])
  end

  def object_type do
    StreamData.member_of(["Repository", "Commit", "PullRequest", "Agent", "Artifact", "Receipt"])
  end

  def object_id(prefix \\ "obj") do
    StreamData.map(StreamData.integer(1..1000), fn n -> "#{prefix}_#{n}" end)
  end

  def agent_id do
    StreamData.map(StreamData.integer(1..100), fn n -> "agent-#{n}" end)
  end

  def iso_timestamp do
    StreamData.map(StreamData.integer(1_700_000_000..1_780_000_000), fn sec ->
      DateTime.from_unix!(sec) |> DateTime.to_iso8601()
    end)
  end

  def ocel_object_generator do
    StreamData.fixed_map(%{
      "id" => object_id(),
      "type" => object_type(),
      "attributes" => StreamData.constant(%{"env" => "test"})
    })
  end

  def ocel_event_generator(available_objects \\ ["obj_1", "obj_2"]) do
    StreamData.fixed_map(%{
      "id" => StreamData.map(StreamData.integer(1..100_000), &"ev_#{&1}"),
      "activity" => activity_name(),
      "timestamp" => iso_timestamp(),
      "objects" =>
        StreamData.list_of(StreamData.member_of(available_objects), min_length: 1, max_length: 3),
      "attributes" =>
        StreamData.fixed_map(%{
          "lifecycle" => StreamData.member_of(["start", "stop", "complete"]),
          "agent_id" => agent_id()
        })
    })
  end

  def batch_envelope_generator do
    StreamData.fixed_map(%{
      "schema" => StreamData.constant("chatgpt-cloud-ocel/1"),
      "producer" =>
        StreamData.fixed_map(%{
          "agent_id" => agent_id(),
          "run_id" => StreamData.map(StreamData.integer(100..999), &"run_#{&1}"),
          "runtime" => StreamData.constant("beam-otp27")
        }),
      "sequence" => StreamData.integer(1..10_000),
      "previous_digest" => StreamData.constant(nil),
      "objects" =>
        StreamData.constant(%{
          "obj_1" => %{"id" => "obj_1", "type" => "Repository", "name" => "ex4pm"},
          "obj_2" => %{"id" => "obj_2", "type" => "Agent", "name" => "cloud-agent"}
        }),
      "events" =>
        StreamData.list_of(ocel_event_generator(["obj_1", "obj_2"]),
          min_length: 1,
          max_length: 10
        )
    })
  end
end
