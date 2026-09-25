defmodule Ex4pm.Aloop do
  @moduledoc """
  Independent online process intelligence over ALOOP (autonomous-loop) OCEL 2.0
  event logs.

  This is a canonical semantic object (`lib/ex4pm/`, alongside `Ex4pm.OCEL`).
  It ingests an ALOOP OCEL 2.0 log through `Ex4pm.OCEL.normalize/1` and answers,
  machine-readably and purely from the log (never from any agent's own
  declaration of autonomy):

    * did recurrence occur (loop depth per episode)?
    * was a human causal edge present (a `human`-origin action and its
      directly-follows edge)?
    * did a provider replacement occur, and was it substitution-equivalent
      (the replacement provider re-executed claim -> start -> receipt)?
    * was every DO (`actuate`) followed by a receipt (`receipt.persist`)?
      The violations are orphan consequences: actuation with no downstream
      receipt/consumer.
    * did every receipt feed a later observation where expected?
    * what process variants occurred?
    * where did the observed process diverge from the ALOOP model
      (off-vocabulary activity, post-terminal activity, unreceipted DO,
      unconsumed receipt, missing episode boundaries)?

    and additionally: directly-follows graph, precision of the observed log
    against the admitted ALOOP directly-follows model, and repair/replan
    chain detection.

  The admitted ALOOP model is `model_edges/0` plus the vocabularies
  (`event_classes/0`, `object_types/0`). `conformance/1` reports every
  observed violation; `precision/1` is the fraction of observed
  directly-follows edges that the model admits.

  All functions are pure: same log in, byte-identical receipt out. No wall
  clock, no randomness. `analysis_receipt/1` is JSON-encodable without
  transformation.
  """

  alias Ex4pm.{Event, EventLog, OCEL}

  @event_classes ~w(
    episode.start observe gap.detect candidate.construct candidate.admit
    plan.select workorder.issue provider.select worker.claim execution.start
    tool.admit actuate checkpoint execution.crash receipt.persist verify
    falsifier.run benchmark.run failure.detect reconcile replan
    provider.replace commit merge reobserve goal.satisfied goal.blocked
    episode.terminal
  )a

  @object_types ~w(
    Episode Objective Requirement WorkOrder Authority Repository Subject
    Provider Worker WorkerRun Plan Capability Candidate Consequence Evidence
    Receipt Failure Benchmark Release
  )a

  @qualifiers ~w(subject originAuthority provider worker input output evidence
                 consequence receipt parentEpisode predecessor)a

  @do_activity "actuate"
  @receipt_activity "receipt.persist"
  @terminal_activity "episode.terminal"
  @loop_head "gap.detect"
  @observation_activities ~w(observe reobserve)
  @human_origin "human"
  @no_episode :__outside_any_episode__

  @model_edges MapSet.new(~w(
    episode.start|observe
    observe|gap.detect observe|goal.satisfied observe|goal.blocked
    reobserve|gap.detect reobserve|goal.satisfied reobserve|goal.blocked
    gap.detect|candidate.construct
    candidate.construct|candidate.admit
    candidate.admit|plan.select
    plan.select|workorder.issue
    workorder.issue|provider.select workorder.issue|worker.claim
    provider.select|worker.claim
    worker.claim|execution.start
    execution.start|tool.admit execution.start|actuate
      execution.start|execution.crash
    tool.admit|actuate
    actuate|checkpoint
    checkpoint|receipt.persist checkpoint|goal.satisfied checkpoint|goal.blocked
    execution.crash|failure.detect
    failure.detect|provider.replace failure.detect|replan failure.detect|reconcile
    provider.replace|provider.select
    replan|plan.select
    reconcile|verify
    receipt.persist|verify
    verify|falsifier.run verify|commit verify|benchmark.run
    falsifier.run|commit falsifier.run|verify
    benchmark.run|commit
    commit|merge commit|reobserve commit|goal.satisfied
    merge|reobserve merge|goal.satisfied
    goal.satisfied|episode.terminal
    goal.blocked|episode.terminal
  )|> Enum.map(&String.split(&1, "|") |> List.to_tuple()))

  # -- Vocabulary ------------------------------------------------------------

  def event_classes, do: Enum.map(@event_classes, &to_string/1)

  def object_types, do: Enum.map(@object_types, &to_string/1)

  def qualifiers, do: Enum.map(@qualifiers, &to_string/1)

  @doc "The admitted ALOOP directly-follows model: a MapSet of {from_activity, to_activity} tuples."
  def model_edges, do: @model_edges

  # -- Ingestion and episode segmentation ------------------------------------

  @doc """
  Ingests a raw OCEL 2.0 map (or passes through an already-normalized
  `Ex4pm.EventLog`) into the canonical event-log IR.
  """
  def ingest(%EventLog{} = log), do: {:ok, log}
  def ingest(raw), do: OCEL.normalize(raw)

  @doc """
  Segments a normalized log into `%{episode_id => [events sorted by time]}`
  (events referencing no Episode object land under `#{inspect(@no_episode)}`).
  """
  def episodes(%EventLog{} = log) do
    episode_ids =
      log.objects
      |> Map.values()
      |> Enum.filter(&(equivalent_type(&1.type, "Episode")))
      |> MapSet.new(& &1.id)

    log.events
    |> Enum.sort_by(&event_sort_key/1)
    |> Enum.reduce(%{}, fn event, acc ->
      ep = Enum.find(event.object_ids, &MapSet.member?(episode_ids, &1)) || @no_episode
      Map.update(acc, ep, [event], &[event | &1])
    end)
    |> Map.new(fn {ep, events} -> {ep, Enum.reverse(events)} end)
  end

  # -- Recurrence / loop depth -------------------------------------------------

  @doc "Per-episode loop depth: the number of `gap.detect` loop iterations."
  def loop_depths(%EventLog{} = log) do
    log
    |> episodes()
    |> Map.new(fn {ep, events} ->
      {ep, Enum.count(events, &(&1.activity == @loop_head))}
    end)
  end

  @doc "`true` when at least one episode ran the loop to a second iteration."
  def recurrence?(%EventLog{} = log) do
    log |> loop_depths() |> Map.values() |> Enum.any?(&(&1 >= 2))
  end

  # -- Human causal edges ------------------------------------------------------

  @doc """
  Human causal edges: every event attributed `originAuthority: "human"`
  together with its directly-follows edge inside the same episode.
  """
  def human_causal_edges(%EventLog{} = log) do
    log
    |> episodes()
    |> Enum.flat_map(fn {ep, events} ->
      events
      |> Enum.with_index()
      |> Enum.flat_map(fn {event, i} ->
        case human_origin?(event) do
          false ->
            []

          true ->
            next = Enum.at(events, i + 1)

            if next do
              [
                %{
                  "episode" => episode_name(ep),
                  "event_id" => event.id,
                  "activity" => event.activity,
                  "next_activity" => next.activity,
                  "next_event_id" => next.id
                }
              ]
            else
              [%{"episode" => episode_name(ep), "event_id" => event.id,
                 "activity" => event.activity, "next_activity" => nil,
                 "next_event_id" => nil}]
            end
        end
      end)
    end)
  end

  def human_causal_edge_present?(%EventLog{} = log), do: human_causal_edges(log) != []

  defp human_origin?(%Event{} = event) do
    event.attributes["originAuthority"] == @human_origin
  end

  # -- Provider replacement / substitution ---------------------------------------

  @doc "Provider replacements observed, with substitution-equivalence verdicts."
  def provider_replacements(%EventLog{} = log) do
    log
    |> episodes()
    |> Enum.flat_map(fn {ep, events} ->
      events
      |> Enum.with_index()
      |> Enum.flat_map(fn {event, i} ->
        if event.activity == "provider.replace" do
          [
            %{
              "episode" => episode_name(ep),
              "event_id" => event.id,
              "from_provider" => event.attributes["from_provider"],
              "to_provider" => event.attributes["to_provider"],
              "substitution_equivalent" => substitution_equivalent?(Enum.drop(events, i + 1))
            }
          ]
        else
          []
        end
      end)
    end)
  end

  def provider_replacement_occurred?(%EventLog{} = log) do
    provider_replacements(log) != []
  end

  @doc """
  A replacement is substitution-equivalent when the replacement provider
  re-executes the execution spine in order: `worker.claim` -> `execution.start`
  -> ... -> `receipt.persist`.
  """
  def substitution_equivalent?(suffix_events) do
    activities = Enum.map(suffix_events, & &1.activity)
    claim = Enum.find_index(activities, &(&1 == "worker.claim"))
    start_i = Enum.find_index(activities, &(&1 == "execution.start"))
    receipt = Enum.find_index(activities, &(&1 == @receipt_activity))

    claim && start_i && receipt && claim < start_i && start_i < receipt
  end

  # -- DO / receipt coverage (orphan consequences) ---------------------------------

  @doc """
  Orphan consequences: `actuate` events with no `receipt.persist` later in the
  same episode (actuation with no downstream receipt/consumer).
  """
  def orphan_dos(%EventLog{} = log) do
    log
    |> episodes()
    |> Enum.flat_map(fn {ep, events} ->
      events
      |> Enum.with_index()
      |> Enum.flat_map(fn {event, i} ->
        if event.activity == @do_activity do
          receipted? =
            events
            |> Enum.drop(i + 1)
            |> Enum.any?(&(&1.activity == @receipt_activity))

          if receipted? do
            []
          else
            [%{"episode" => episode_name(ep), "event_id" => event.id,
               "consequence" => event.attributes["consequence"]}]
          end
        else
          []
        end
      end)
    end)
  end

  def every_do_receipted?(%EventLog{} = log), do: orphan_dos(log) == []

  # -- Receipt consumption ---------------------------------------------------------

  @doc """
  Receipts that were persisted but never entered the observation stream: no
  `observe`/`reobserve` consumes them later in the same episode, AND a new
  loop iteration (`gap.detect`) starts afterwards — i.e. the episode kept
  working without the receipt ever feeding an observation. A receipt after
  which only the episode's own closing goal occurs is consumed-by-terminal,
  not unconsumed.
  """
  def unconsumed_receipts(%EventLog{} = log) do
    log
    |> episodes()
    |> Enum.flat_map(fn {ep, events} ->
      events
      |> Enum.with_index()
      |> Enum.flat_map(fn {event, i} ->
        if event.activity == @receipt_activity do
          suffix = Enum.drop(events, i + 1)

          fed_observation? = Enum.any?(suffix, &(&1.activity in @observation_activities))
          new_iteration_started? = Enum.any?(suffix, &(&1.activity == @loop_head))

          if fed_observation? or not new_iteration_started? do
            []
          else
            [%{"episode" => episode_name(ep), "event_id" => event.id,
               "receipt" => event.attributes["receipt"]}]
          end
        else
          []
        end
      end)
    end)
  end

  def every_receipt_consumed?(%EventLog{} = log), do: unconsumed_receipts(log) == []

  # -- DFG, variants, precision ----------------------------------------------------

  @doc """
  Directly-follows graph over the whole log as sorted
  `[%{"from" =>, "to" =>, "count" =>}]`. Edges never cross episode boundaries.
  """
  def dfg(%EventLog{} = log) do
    log
    |> episodes()
    |> Enum.flat_map(fn {_ep, events} -> Enum.zip(events, Enum.drop(events, 1)) end)
    |> Enum.frequencies_by(fn {a, b} -> {a.activity, b.activity} end)
    |> Enum.map(fn {{from, to}, count} ->
      %{"from" => from, "to" => to, "count" => count}
    end)
    |> Enum.sort_by(&{&1["from"], &1["to"]})
  end

  @doc """
  Process variants: distinct per-episode activity sequences, each with a
  stable content hash id, the episodes exhibiting it, and its count.
  """
  def variants(%EventLog{} = log) do
    log
    |> episodes()
    |> Enum.reject(fn {ep, _events} -> ep == @no_episode end)
    |> Enum.group_by(fn {_ep, events} -> Enum.map(events, & &1.activity) end)
    |> Enum.map(fn {sequence, group} ->
      %{
        "id" => variant_id(sequence),
        "sequence" => sequence,
        "episodes" => group |> Enum.map(&episode_name(elem(&1, 0))) |> Enum.sort(),
        "count" => length(group)
      }
    end)
    |> Enum.sort_by(& &1["id"])
  end

  defp variant_id(sequence) do
    :crypto.hash(:sha256, Enum.join(sequence, "\\u001f"))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  @doc """
  Precision of the observed log against the admitted ALOOP model: the fraction
  of observed directly-follows edges the model admits. `1.0` when every
  observed edge is lawful; `nil` when the log has no edges.
  """
  def precision(%EventLog{} = log) do
    edges = dfg(log)

    total = Enum.sum(Enum.map(edges, & &1["count"]))

    lawful_total =
      Enum.sum(Enum.map(edges, fn e ->
        if MapSet.member?(@model_edges, {e["from"], e["to"]}), do: e["count"], else: 0
      end))

    if total == 0, do: nil, else: Float.round(lawful_total / total, 4)
  end

  # -- Conformance (divergence from the ALOOP model) ---------------------------------

  @doc """
  Every observed divergence from the ALOOP model:
  `:off_vocabulary_activity`, `:post_terminal_activity`,
  `:missing_episode_start`, `:missing_episode_terminal`,
  `:event_outside_any_episode`, `:unreceipted_do`, `:unconsumed_receipt`,
  `:missing_origin_authority`, `:provider_replace_missing_qualifiers`,
  `:off_model_edge`.
  """
  def divergences(%EventLog{} = log) do
    Enum.concat([
      vocabulary_divergences(log),
      structure_divergences(log),
      orphan_dos(log) |> Enum.map(&divergence("unreceipted_do", &1["episode"],
        "actuate #{&1["event_id"]} has no downstream receipt.persist")),
      unconsumed_receipts(log) |> Enum.map(&divergence("unconsumed_receipt", &1["episode"],
        "receipt.persist #{&1["event_id"]} fed no later observation and closed no episode")),
      missing_origin_authority(log),
      off_model_edges(log)
    ])
    |> Enum.sort_by(&{&1["episode"], &1["type"], &1["detail"]})
  end

  def conformant?(%EventLog{} = log), do: divergences(log) == []

  defp vocabulary_divergences(log) do
    admitted = MapSet.new(event_classes())

    log.events
    |> Enum.reject(&MapSet.member?(admitted, &1.activity))
    |> Enum.map(&divergence("off_vocabulary_activity", episode_of(log, &1),
      "activity #{&1.activity} is outside the ALOOP event vocabulary"))
  end

  defp structure_divergences(log) do
    log
    |> episodes()
    |> Enum.flat_map(fn {ep, events} ->
      ep_name = episode_name(ep)
      activities = Enum.map(events, & &1.activity)
      terminal_index = Enum.find_index(activities, &(&1 == @terminal_activity))

      post_terminal =
        case terminal_index do
          nil ->
            []

          idx ->
            events
            |> Enum.drop(idx + 1)
            |> Enum.reject(&(&1.activity == @terminal_activity))
            |> Enum.map(&divergence("post_terminal_activity", ep_name,
              "#{&1.activity} #{&1.id} occurs after episode.terminal"))
        end

      pre =
        case List.first(activities) do
          "episode.start" -> []
          nil -> []
          _ -> [divergence("missing_episode_start", ep_name, "episode does not open with episode.start")]
        end

      missing_terminal =
        if terminal_index, do: [], else: [divergence("missing_episode_terminal", ep_name, "episode has no episode.terminal")]

      outside =
        if ep == @no_episode do
          Enum.map(events, &divergence("event_outside_any_episode", "none",
            "#{&1.activity} #{&1.id} references no Episode object"))
        else
          []
        end

      Enum.concat([pre, missing_terminal, post_terminal, outside])
    end)
  end

  defp missing_origin_authority(log) do
    log.events
    |> Enum.filter(&(&1.activity == "candidate.construct"))
    |> Enum.reject(&is_binary(&1.attributes["originAuthority"]))
    |> Enum.map(&divergence("missing_origin_authority", episode_of(log, &1),
      "candidate.construct #{&1.id} carries no originAuthority qualifier"))
  end

  defp off_model_edges(log) do
    dfg(log)
    |> Enum.reject(&MapSet.member?(@model_edges, {&1["from"], &1["to"]}))
    |> Enum.map(&divergence("off_model_edge", "all",
      "directly-follows edge #{&1["from"]} -> #{&1["to"]} (observed #{&1["count"]}x) is outside the ALOOP model"))
  end

  # -- Repair / replan ----------------------------------------------------------------

  @doc """
  Repair/replan chains: `execution.crash -> failure.detect -> {provider.replace
  | replan | reconcile}` occurrences, with the recovery activity observed.
  """
  def repair_replan_chains(%EventLog{} = log) do
    log
    |> episodes()
    |> Enum.flat_map(fn {ep, events} ->
      events
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.flat_map(fn
        [%Event{} = crash, %Event{} = detect, %Event{} = recovery] ->
          if crash.activity == "execution.crash" and detect.activity == "failure.detect" and
               recovery.activity in ["provider.replace", "replan", "reconcile"] do
            [%{"episode" => episode_name(ep), "crash_event_id" => crash.id,
               "recovery" => recovery.activity, "recovery_event_id" => recovery.id}]
          else
            []
          end

        _ ->
          []
      end)
    end)
    |> Enum.sort_by(&{&1["episode"], &1["crash_event_id"]})
  end

  # -- Analysis receipt -----------------------------------------------------------------

  @doc """
  Full machine-readable analysis receipt (JSON-encodable, deterministic).
  Accepts a raw OCEL 2.0 map or a normalized `Ex4pm.EventLog`.
  """
  def analysis_receipt(source) do
    source_meta = source_metadata(source)

    case ingest(source) do
      {:ok, log} ->
        %{
          "schema" => "ex4pm.aloop.analysis_receipt/v1",
          "standing" => "ALIVE",
          "source" => source_meta,
          "counts" => %{
            "events" => length(log.events),
            "objects" => map_size(log.objects),
            "episodes" => log |> episodes() |> Map.delete(@no_episode) |> map_size()
          },
          "answers" => %{
            "recurrence_occurred" => recurrence?(log),
            "loop_depths" => loop_depths(log) |> Map.new(fn {k, v} -> {episode_name(k), v} end),
            "human_causal_edge_present" => human_causal_edge_present?(log),
            "human_causal_edges" => human_causal_edges(log),
            "provider_replacement_occurred" => provider_replacement_occurred?(log),
            "provider_replacements" => provider_replacements(log),
            "every_do_followed_by_receipt" => every_do_receipted?(log),
            "orphan_dos" => orphan_dos(log),
            "every_receipt_fed_later_observation" => every_receipt_consumed?(log),
            "unconsumed_receipts" => unconsumed_receipts(log),
            "conformant_to_aloop_model" => conformant?(log),
            "divergences" => divergences(log),
            "precision" => precision(log),
            "variants" => variants(log),
            "repair_replan_chains" => repair_replan_chains(log)
          },
          "dfg" => dfg(log)
        }

      {:error, refusal} ->
        %{
          "schema" => "ex4pm.aloop.analysis_receipt/v1",
          "standing" => "REFUSED",
          "source" => source_meta,
          "refusal" => %{
            "code" => refusal.code,
            "message" => refusal.message
          }
        }
    end
  end

  # -- Shared helpers -----------------------------------------------------------------

  defp source_metadata(%EventLog{}), do: %{"format" => "ex4pm EventLog", "corpus_status" => "UNKNOWN"}
  defp source_metadata(raw) when is_map(raw) do
    producer = raw["producer"]
    note = if is_map(producer), do: producer["note"], else: nil

    %{
      "format" => "ocel_v2_map",
      "producer" => (is_map(producer) && producer["name"]) || nil,
      "corpus_status" => corpus_status(note || "")
    }
  end
  defp source_metadata(other), do: %{"format" => "unknown", "corpus_status" => "UNKNOWN", "raw" => inspect(other)}

  defp corpus_status(note) do
    if note =~ "RECONSTRUCTED", do: "RECONSTRUCTED", else: "OBSERVED"
  end

  defp equivalent_type(left, right), do: to_string(left) == to_string(right)

  defp episode_of(log, %Event{} = event) do
    log
    |> episodes()
    |> Enum.find_value(@no_episode, fn {ep, events} ->
      if Enum.any?(events, &(&1.id == event.id)), do: episode_name(ep), else: nil
    end)
  end

  defp episode_name(@no_episode), do: "none"
  defp episode_name(ep) when is_binary(ep), do: ep
  defp episode_name(ep), do: to_string(ep)

  defp divergence(type, episode, detail) do
    %{"type" => type, "episode" => episode, "detail" => detail}
  end

  defp event_sort_key(%Event{} = event) do
    {time_key(event.timestamp), event.id}
  end

  defp time_key(%DateTime{} = t), do: DateTime.to_iso8601(t)
  defp time_key(t) when is_binary(t), do: t
  defp time_key(t), do: to_string(t)
end
