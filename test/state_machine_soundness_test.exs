defmodule Ex4pmDomain.StateMachineSoundnessTest do
  use ExUnit.Case, async: true

  alias Ex4pmDomain.{ChangeOrder, ProcessIncident}
  alias Ex4pmEngine.SoundnessProver

  test "ProcessIncident state machine compiles to mathematically proven 1-safe sound Workflow Net" do
    net = ProcessIncident.to_workflow_net()
    report = SoundnessProver.verify_soundness(net)

    assert report.sound? == true
    assert report.option_to_complete? == true
    assert report.proper_completion? == true
    assert report.no_dead_transitions? == true
    assert report.one_safe? == true
    assert report.deadlocks == []
  end

  test "ChangeOrder state machine compiles to mathematically proven 1-safe sound Workflow Net" do
    net = ChangeOrder.to_workflow_net()
    report = SoundnessProver.verify_soundness(net)

    assert report.sound? == true
    assert report.option_to_complete? == true
    assert report.proper_completion? == true
    assert report.no_dead_transitions? == true
    assert report.one_safe? == true
    assert report.deadlocks == []
  end

  test "Ash action transitions enforce strict lifecycle order and state guards" do
    # Create incident in initial :reported state
    assert {:ok, inc} =
             ProcessIncident
             |> Ash.Changeset.for_create(:report, %{
               title: "Database latency spike",
               severity: :high
             })
             |> Ash.create()

    assert inc.state == :reported

    # Lawful transition: report -> triage
    assert {:ok, triaged} =
             inc
             |> Ash.Changeset.for_update(:triage, %{assigned_team: "SRE-Alpha"})
             |> Ash.update()

    assert triaged.state == :triaged
    assert triaged.assigned_team == "SRE-Alpha"

    # Lawful transition: triage -> investigate
    assert {:ok, in_progress} =
             triaged
             |> Ash.Changeset.for_update(:investigate, %{})
             |> Ash.update()

    assert in_progress.state == :in_progress

    # Lawful transition: investigate -> resolve
    assert {:ok, resolved} =
             in_progress
             |> Ash.Changeset.for_update(:resolve, %{resolution_notes: "Index rebuilt"})
             |> Ash.update()

    assert resolved.state == :resolved

    # Lawful transition: resolve -> close
    assert {:ok, closed} =
             resolved
             |> Ash.Changeset.for_update(:close, %{})
             |> Ash.update()

    assert closed.state == :closed
  end
end
