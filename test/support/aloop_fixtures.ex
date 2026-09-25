defmodule Ex4pm.Test.AloopFixtures do
  @moduledoc """
  RECONSTRUCTED synthetic ALOOP OCEL 2.0 fixture corpus (lane 9,
  ALOOP-ZCODE-DOGFOOD-001).

  This corpus is reconstructed, not observed: it is a deterministic,
  hand-seeded synthetic log whose only purpose is to make every
  `Ex4pm.Aloop` analysis runnable and falsifiable today. It contains no
  observed production data. Determinism is by construction (every id,
  timestamp, and attribute is a fixed literal; there is no random source),
  which is the seed discipline: regenerating the corpus twice yields
  byte-identical JSON.

  Four episodes cover the four required shapes:

    * `ep-1` -- a clean recurrent episode: two full loop iterations, every
      DO (actuate) followed by a receipt.persist, each receipt consumed by
      a later observe/reobserve.
    * `ep-2` -- a planted human causal edge: one candidate.construct event
      carries `originAuthority: "human"`, so the directly-follows edge
      candidate.construct -> candidate.admit is a human->next-action edge.
    * `ep-3` -- a provider substitution: execution.crash -> failure.detect
      -> provider.replace (p-flash -> p-zcode) -> re-execution, so the
      provider.replace chain is substitution-equivalent (the replacement
      provider re-executes claim/start/actuate/receipt).
    * `ep-4` -- an orphan DO: an actuate with NO downstream
      receipt.persist (the episode ends goal.blocked).

  The corrupted variants (`corrupted/1`) each flip exactly one semantic
  signal so every analysis has an anti-vacuity falsifier: a conformance or
  coverage check that still passed the corresponding corruption would carry
  no bits.
  """

  @base_date "2026-09-25T"
  @seed "aloop-dogfood-001/lane-9/reconstructed/2026-09-25"

  # -- ALOOP vocabulary (mirrors Ex4pm.Aloop; kept in fixtures so the test
  #    corpus can be validated against the module's own admission lists) ----

  def event_classes do
    Ex4pm.Aloop.event_classes()
  end

  def object_types do
    Ex4pm.Aloop.object_types()
  end

  def seed, do: @seed

  # -- Public corpus builders ------------------------------------------------

  @doc "Full four-episode OCEL 2.0 map (clean + human edge + provider substitution + orphan DO)."
  def corpus do
    log(%{
      "ep-1" => clean_episode_events(),
      "ep-2" => human_edge_episode_events(),
      "ep-3" => provider_substitution_episode_events(),
      "ep-4" => orphan_do_episode_events()
    })
  end

  @doc "Single-episode OCEL 2.0 map: the clean recurrent episode only."
  def clean_episode_log do
    log(%{"ep-1" => clean_episode_events()})
  end

  @doc "Single-episode OCEL 2.0 map: the planted-human-edge episode only."
  def human_edge_episode_log do
    log(%{"ep-2" => human_edge_episode_events()})
  end

  @doc "Single-episode OCEL 2.0 map: the provider-substitution episode only."
  def provider_substitution_episode_log do
    log(%{"ep-3" => provider_substitution_episode_events()})
  end

  @doc "Single-episode OCEL 2.0 map: the orphan-DO episode only."
  def orphan_do_episode_log do
    log(%{"ep-4" => orphan_do_episode_events()})
  end

  @corruptions [
    :orphan_do_removed_receipt,
    :human_edge_relabeled,
    :provider_replace_removed,
    :off_vocabulary_activity,
    :unconsumed_receipt,
    :post_terminal_activity
  ]

  def corruptions, do: @corruptions

  @doc """
  Applies one seeded corruption to an OCEL map. Each corruption flips
  exactly the semantic signal it is the falsifier for:

    * `:orphan_do_removed_receipt` -- drops ep-1's second receipt.persist,
      leaving its actuate unreceipted (orphan-consequence falsifier).
    * `:human_edge_relabeled` -- relabels ep-2's human originAuthority to
      autonomous (human-causal-edge falsifier).
    * `:provider_replace_removed` -- drops ep-3's provider.replace event
      (provider-replacement falsifier).
    * `:off_vocabulary_activity` -- renames ep-1's commit to
      "deploy_to_prod", an activity outside the ALOOP vocabulary
      (divergence/conformance falsifier).
    * `:unconsumed_receipt` -- drops ep-1's reobserve, so a persisted
      receipt never feeds a later observation (recurrence falsifier).
    * `:post_terminal_activity` -- appends an observe after ep-1's
      episode.terminal (model-order falsifier).
  """
  def corrupted(log_map, corruption) when corruption in @corruptions do
    events =
      log_map["events"]
      |> apply_corruption(corruption)
      |> Enum.sort_by(&{&1["timestamp"], &1["id"]})

    Map.put(log_map, "events", events)
  end

  defp apply_corruption(events, :orphan_do_removed_receipt),
    do: Enum.reject(events, &(&1["id"] == "e1-28"))

  defp apply_corruption(events, :human_edge_relabeled),
    do:
      Enum.map(events, fn e ->
        if e["id"] == "e2-03" do
          put_in(e["attributes"]["originAuthority"], "autonomous")
        else
          e
        end
      end)

  defp apply_corruption(events, :provider_replace_removed),
    do: Enum.reject(events, &(&1["id"] == "e3-12"))

  defp apply_corruption(events, :off_vocabulary_activity),
    do:
      Enum.map(events, fn e ->
        if e["id"] == "e1-16" do
          Map.put(e, "activity", "deploy_to_prod")
        else
          e
        end
      end)

  defp apply_corruption(events, :unconsumed_receipt),
    do: Enum.reject(events, &(&1["id"] == "e1-17"))

  defp apply_corruption(events, :post_terminal_activity),
    do:
      events ++
        [
          ev("e1-33", "observe", 33, ["ep-1", "obj-1"], %{})
        ]

  # -- Episode definitions ---------------------------------------------------

  defp clean_episode_events do
    [
      ev("e1-00", "episode.start", 0, ["ep-1"], %{}),
      ev("e1-01", "observe", 1, ["ep-1", "obj-1"], %{}),
      ev("e1-02", "gap.detect", 2, ["ep-1"], %{}),
      ev("e1-03", "candidate.construct", 3, ["ep-1"], %{"originAuthority" => "autonomous"}),
      ev("e1-04", "candidate.admit", 4, ["ep-1"], %{}),
      ev("e1-05", "plan.select", 5, ["ep-1"], %{}),
      ev("e1-06", "workorder.issue", 6, ["ep-1", "wo-1"], %{}),
      ev("e1-07", "provider.select", 7, ["ep-1", "p-zcode"], %{"provider" => "p-zcode"}),
      ev("e1-08", "worker.claim", 8, ["ep-1", "w-agent-1"], %{}),
      ev("e1-09", "execution.start", 9, ["ep-1"], %{}),
      ev("e1-10", "tool.admit", 10, ["ep-1"], %{}),
      ev("e1-11", "actuate", 11, ["ep-1"], %{"consequence" => "c-1a"}),
      ev("e1-12", "checkpoint", 12, ["ep-1"], %{}),
      ev("e1-13", "receipt.persist", 13, ["ep-1", "r-1a"], %{"receipt" => "r-1a"}),
      ev("e1-14", "verify", 14, ["ep-1"], %{}),
      ev("e1-15", "falsifier.run", 15, ["ep-1"], %{}),
      ev("e1-16", "commit", 16, ["ep-1"], %{}),
      ev("e1-17", "reobserve", 17, ["ep-1", "obj-1"], %{}),
      ev("e1-18", "gap.detect", 18, ["ep-1"], %{}),
      ev("e1-19", "candidate.construct", 19, ["ep-1"], %{"originAuthority" => "autonomous"}),
      ev("e1-20", "candidate.admit", 20, ["ep-1"], %{}),
      ev("e1-21", "plan.select", 21, ["ep-1"], %{}),
      ev("e1-22", "workorder.issue", 22, ["ep-1", "wo-1"], %{}),
      ev("e1-23", "worker.claim", 23, ["ep-1", "w-agent-1"], %{}),
      ev("e1-24", "execution.start", 24, ["ep-1"], %{}),
      ev("e1-25", "tool.admit", 25, ["ep-1"], %{}),
      ev("e1-26", "actuate", 26, ["ep-1"], %{"consequence" => "c-1b"}),
      ev("e1-27", "checkpoint", 27, ["ep-1"], %{}),
      ev("e1-28", "receipt.persist", 28, ["ep-1", "r-1b"], %{"receipt" => "r-1b"}),
      ev("e1-29", "verify", 29, ["ep-1"], %{}),
      ev("e1-30", "commit", 30, ["ep-1"], %{}),
      ev("e1-31", "goal.satisfied", 31, ["ep-1"], %{}),
      ev("e1-32", "episode.terminal", 32, ["ep-1"], %{})
    ]
  end

  defp human_edge_episode_events do
    [
      ev("e2-00", "episode.start", 0, ["ep-2"], %{}),
      ev("e2-01", "observe", 1, ["ep-2", "obj-2"], %{}),
      ev("e2-02", "gap.detect", 2, ["ep-2"], %{}),
      ev("e2-03", "candidate.construct", 3, ["ep-2"], %{"originAuthority" => "human"}),
      ev("e2-04", "candidate.admit", 4, ["ep-2"], %{}),
      ev("e2-05", "plan.select", 5, ["ep-2"], %{}),
      ev("e2-06", "workorder.issue", 6, ["ep-2", "wo-2"], %{}),
      ev("e2-07", "provider.select", 7, ["ep-2", "p-zcode"], %{"provider" => "p-zcode"}),
      ev("e2-08", "worker.claim", 8, ["ep-2", "w-agent-2"], %{}),
      ev("e2-09", "execution.start", 9, ["ep-2"], %{}),
      ev("e2-10", "tool.admit", 10, ["ep-2"], %{}),
      ev("e2-11", "actuate", 11, ["ep-2"], %{"consequence" => "c-2a"}),
      ev("e2-12", "checkpoint", 12, ["ep-2"], %{}),
      ev("e2-13", "receipt.persist", 13, ["ep-2", "r-2a"], %{"receipt" => "r-2a"}),
      ev("e2-14", "verify", 14, ["ep-2"], %{}),
      ev("e2-15", "commit", 15, ["ep-2"], %{}),
      ev("e2-16", "goal.satisfied", 16, ["ep-2"], %{}),
      ev("e2-17", "episode.terminal", 17, ["ep-2"], %{})
    ]
  end

  defp provider_substitution_episode_events do
    [
      ev("e3-00", "episode.start", 0, ["ep-3"], %{}),
      ev("e3-01", "observe", 1, ["ep-3", "obj-3"], %{}),
      ev("e3-02", "gap.detect", 2, ["ep-3"], %{}),
      ev("e3-03", "candidate.construct", 3, ["ep-3"], %{"originAuthority" => "autonomous"}),
      ev("e3-04", "candidate.admit", 4, ["ep-3"], %{}),
      ev("e3-05", "plan.select", 5, ["ep-3"], %{}),
      ev("e3-06", "workorder.issue", 6, ["ep-3", "wo-3"], %{}),
      ev("e3-07", "provider.select", 7, ["ep-3", "p-flash"], %{"provider" => "p-flash"}),
      ev("e3-08", "worker.claim", 8, ["ep-3", "w-agent-3"], %{}),
      ev("e3-09", "execution.start", 9, ["ep-3"], %{}),
      ev("e3-10", "execution.crash", 10, ["ep-3"], %{}),
      ev("e3-11", "failure.detect", 11, ["ep-3"], %{}),
      ev(
        "e3-12",
        "provider.replace",
        12,
        ["ep-3", "p-flash", "p-zcode"],
        %{"from_provider" => "p-flash", "to_provider" => "p-zcode"}
      ),
      ev("e3-13", "provider.select", 13, ["ep-3", "p-zcode"], %{"provider" => "p-zcode"}),
      ev("e3-14", "worker.claim", 14, ["ep-3", "w-agent-4"], %{}),
      ev("e3-15", "execution.start", 15, ["ep-3"], %{}),
      ev("e3-16", "tool.admit", 16, ["ep-3"], %{}),
      ev("e3-17", "actuate", 17, ["ep-3"], %{"consequence" => "c-3a"}),
      ev("e3-18", "checkpoint", 18, ["ep-3"], %{}),
      ev("e3-19", "receipt.persist", 19, ["ep-3", "r-3a"], %{"receipt" => "r-3a"}),
      ev("e3-20", "verify", 20, ["ep-3"], %{}),
      ev("e3-21", "commit", 21, ["ep-3"], %{}),
      ev("e3-22", "reobserve", 22, ["ep-3", "obj-3"], %{}),
      ev("e3-23", "goal.satisfied", 23, ["ep-3"], %{}),
      ev("e3-24", "episode.terminal", 24, ["ep-3"], %{})
    ]
  end

  defp orphan_do_episode_events do
    [
      ev("e4-00", "episode.start", 0, ["ep-4"], %{}),
      ev("e4-01", "observe", 1, ["ep-4", "obj-4"], %{}),
      ev("e4-02", "gap.detect", 2, ["ep-4"], %{}),
      ev("e4-03", "candidate.construct", 3, ["ep-4"], %{"originAuthority" => "autonomous"}),
      ev("e4-04", "candidate.admit", 4, ["ep-4"], %{}),
      ev("e4-05", "plan.select", 5, ["ep-4"], %{}),
      ev("e4-06", "workorder.issue", 6, ["ep-4", "wo-4"], %{}),
      ev("e4-07", "provider.select", 7, ["ep-4", "p-zcode"], %{"provider" => "p-zcode"}),
      ev("e4-08", "worker.claim", 8, ["ep-4", "w-agent-5"], %{}),
      ev("e4-09", "execution.start", 9, ["ep-4"], %{}),
      ev("e4-10", "tool.admit", 10, ["ep-4"], %{}),
      ev("e4-11", "actuate", 11, ["ep-4"], %{"consequence" => "c-4a"}),
      ev("e4-12", "checkpoint", 12, ["ep-4"], %{}),
      ev("e4-13", "goal.blocked", 13, ["ep-4"], %{}),
      ev("e4-14", "episode.terminal", 14, ["ep-4"], %{})
    ]
  end

  # -- Assembly --------------------------------------------------------------

  defp log(episode_events) do
    %{
      "schema" => "https://ocel-standard.org/schema/2.0",
      "producer" => %{"name" => "aloop-dogfood-001/lane-9", "note" => "RECONSTRUCTED synthetic fixture, seed: " <> @seed},
      "events" =>
        episode_events
        |> Map.values()
        |> List.flatten()
        |> Enum.sort_by(&{&1["timestamp"], &1["id"]}),
      "objects" => objects(),
      "object_relationships" => object_relationships()
    }
  end

  defp objects do
    episode_objects =
      Enum.map(1..4, fn n ->
        obj("ep-#{n}", "Episode", %{"label" => "reconstructed-episode-#{n}"})
      end)

    objectives = Enum.map(1..4, &obj("obj-#{&1}", "Objective", %{}))

    work_orders = Enum.map(1..4, &obj("wo-#{&1}", "WorkOrder", %{"state" => "issued"}))

    providers = [
      obj("p-zcode", "Provider", %{"name" => "zcode"}),
      obj("p-flash", "Provider", %{"name" => "flash-tier"})
    ]

    workers = [
      obj("w-agent-1", "Worker", %{"kind" => "agent"}),
      obj("w-agent-2", "Worker", %{"kind" => "agent"}),
      obj("w-agent-3", "Worker", %{"kind" => "agent"}),
      obj("w-agent-4", "Worker", %{"kind" => "agent"}),
      obj("w-agent-5", "Worker", %{"kind" => "agent"})
    ]

    receipts = [
      obj("r-1a", "Receipt", %{"exit_status" => 0}),
      obj("r-1b", "Receipt", %{"exit_status" => 0}),
      obj("r-2a", "Receipt", %{"exit_status" => 0}),
      obj("r-3a", "Receipt", %{"exit_status" => 0})
    ]

    consequences = [
      obj("c-1a", "Consequence", %{}),
      obj("c-1b", "Consequence", %{}),
      obj("c-2a", "Consequence", %{}),
      obj("c-3a", "Consequence", %{}),
      obj("c-4a", "Consequence", %{})
    ]

    episode_objects ++ objectives ++ work_orders ++ providers ++ workers ++ receipts ++ consequences
  end

  defp object_relationships do
    Enum.flat_map(1..4, fn n ->
      [
        %{"source_id" => "ep-#{n}", "target_id" => "obj-#{n}", "qualifier" => "subject"},
        %{"source_id" => "ep-#{n}", "target_id" => "wo-#{n}", "qualifier" => "workorder"}
      ]
    end) ++
      [
        %{"source_id" => "ep-3", "target_id" => "p-zcode", "qualifier" => "provider"},
        %{"source_id" => "r-1a", "target_id" => "c-1a", "qualifier" => "consequence"},
        %{"source_id" => "r-1b", "target_id" => "c-1b", "qualifier" => "consequence"},
        %{"source_id" => "r-2a", "target_id" => "c-2a", "qualifier" => "consequence"},
        %{"source_id" => "r-3a", "target_id" => "c-3a", "qualifier" => "consequence"}
      ]
  end

  # -- Primitives ------------------------------------------------------------

  defp obj(id, type, attrs), do: %{"id" => id, "type" => type, "attributes" => attrs}

  defp ev(id, activity, minute, object_ids, attrs) do
    %{
      "id" => id,
      "activity" => activity,
      "timestamp" => ts(minute),
      "object_ids" => object_ids,
      "attributes" => attrs
    }
  end

  defp ts(minute) do
    hh = minute |> div(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    mm = minute |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")

    "#{@base_date}#{hh}:#{mm}:00Z"
  end
end
