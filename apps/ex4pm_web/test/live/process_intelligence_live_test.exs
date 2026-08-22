defmodule Ex4pmWeb.ProcessIntelligenceLiveTest do
  use Ex4pmWeb.ConnCase, async: false

  alias Ex4pm.Engine.OnlineMiner
  alias Ex4pm.Event

  test "mounts live stream dashboard and renders initial UI", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/process-intelligence/live")
    assert html =~ "Process Intelligence Control Plane"
    assert html =~ "LIVE OCEL 2.0"
    assert html =~ "Total Events"
    assert html =~ "Active Agents"
  end

  test "updates LiveView when events are ingested into OnlineMiner", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/process-intelligence/live")

    # Ingest event into OnlineMiner
    event = %Event{
      id: "ev-test-live",
      activity: "github.pr_created",
      timestamp: "2026-08-21T18:20:00Z",
      attributes: %{
        "agent_id" => "chatgpt-cloud-21",
        "run_id" => "run-21",
        "standing" => :alive,
        "repository" => "autofde-lab"
      }
    }

    OnlineMiner.ingest(event)

    # Trigger refresh or check render
    rendered = render_click(view, "refresh")
    assert rendered =~ "chatgpt-cloud-21"
    assert rendered =~ "autofde-lab"
  end
end
