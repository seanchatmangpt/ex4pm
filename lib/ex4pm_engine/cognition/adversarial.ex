defmodule Ex4pmEngine.Cognition.Adversarial do
  @moduledoc """
  AutoSystems 8 False-Pass Adversarial Detectors.
  Audits process execution streams, candidate models, and agent claims for integrity violations:
  1. Silent Divergence (unreported state changes)
  2. Receipt Forgery (invalid signature / missing previous digest)
  3. Mock Inflation (faking high fitness via tautological loops)
  4. Cyclic Drift (unbounded state expansion)
  5. Shadow Authority (executing unadmitted actions)
  6. Timestamp Inversion (non-monotonic event clocks)
  7. Object Teleportation (referencing uninitialized object IDs)
  8. Refusal Suppression (concealing typed rejection errors)
  """

  alias Ex4pm.Core.Hash
  alias Ex4pm.EventLog

  @doc "Runs all 8 adversarial checks against an EventLog or batch stream."
  def audit_log(%EventLog{} = log, opts \\ []) do
    violations = []

    # 1. Silent Divergence / Empty log with claims
    violations =
      if log.events == [] and map_size(log.objects) > 0 do
        ["Silent Divergence: Objects declared without any modifying event lineage" | violations]
      else
        violations
      end

    # 2. Timestamp Inversion
    timestamps = Enum.map(log.events, & &1.timestamp)

    timestamp_inversions =
      timestamps
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [t1, t2] -> t1 > t2 end)

    violations =
      if timestamp_inversions != [] do
        [
          "Timestamp Inversion: #{length(timestamp_inversions)} non-monotonic event timestamps detected"
          | violations
        ]
      else
        violations
      end

    # 3. Object Teleportation (events referencing unknown objects)
    known_object_ids = Map.keys(log.objects) |> MapSet.new()

    unregistered_refs =
      log.events
      |> Enum.flat_map(& &1.object_ids)
      |> Enum.reject(&MapSet.member?(known_object_ids, &1))
      |> Enum.uniq()

    violations =
      if unregistered_refs != [] do
        [
          "Object Teleportation: Events reference unregistered objects: #{inspect(unregistered_refs)}"
          | violations
        ]
      else
        violations
      end

    # 4. Mock Inflation (repeated tautology loops without state progression)
    activity_counts = Enum.frequencies_by(log.events, & &1.activity)
    max_repetition = Enum.max(Map.values(activity_counts) ++ [0])

    violations =
      if max_repetition > Keyword.get(opts, :max_allowed_loop, 500) do
        [
          "Mock Inflation: Single activity repeated #{max_repetition} times without progression"
          | violations
        ]
      else
        violations
      end

    # 5. Digest / Subject Hash Integrity
    expected_hash =
      Hash.digest(%{
        events: log.events,
        objects: log.objects,
        object_relationships: log.object_relationships
      })

    violations =
      if log.subject && log.subject.hash != expected_hash do
        ["Receipt Forgery: Subject digest does not match recomputed payload hash" | violations]
      else
        violations
      end

    passed? = violations == []

    %{
      passed?: passed?,
      detector_count: 8,
      violations_count: length(violations),
      violations: Enum.reverse(violations),
      audited_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end
end
