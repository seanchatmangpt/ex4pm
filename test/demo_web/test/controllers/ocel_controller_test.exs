defmodule Ex4pmWeb.OcelControllerTest do
  use Ex4pmWeb.ConnCase, async: false

  test "POST /api/v1/ocel/events ingests batch envelope and responds 201 Created", %{conn: conn} do
    payload = %{
      "schema" => "chatgpt-cloud-ocel/1",
      "producer" => %{
        "agent_id" => "chatgpt-cloud-17",
        "run_id" => "run-abc",
        "runtime" => "beam-otp27"
      },
      "sequence" => 1,
      "objects" => %{
        "repo-1" => %{"id" => "repo-1", "type" => "Repository", "name" => "gymact"}
      },
      "events" => [
        %{
          "id" => "ev-001",
          "activity" => "github.commit",
          "timestamp" => "2026-08-21T18:14:00Z",
          "relationships" => [%{"objectId" => "repo-1", "qualifier" => "source"}],
          "agent_id" => "chatgpt-cloud-17",
          "run_id" => "run-abc",
          "repository" => "gymact"
        }
      ]
    }

    conn = post(conn, ~p"/api/v1/ocel/events", payload)
    assert response = json_response(conn, 201)
    assert response["status"] == "success"
    assert response["data"]["status"] == "ingested"
    assert response["data"]["agent_id"] == "chatgpt-cloud-17"
    assert response["data"]["event_count"] == 1
  end

  test "POST /api/v1/ocel/events rejects invalid envelope with 422 Unprocessable Entity", %{
    conn: conn
  } do
    invalid_payload = %{
      "schema" => "chatgpt-cloud-ocel/1",
      "producer" => %{"agent_id" => "agent-1"},
      "sequence" => -1,
      "events" => []
    }

    conn = post(conn, ~p"/api/v1/ocel/events", invalid_payload)
    assert response = json_response(conn, 422)
    assert response["status"] == "refused"
    assert response["standing"] == "refused"
    assert response["error"]["code"] == "invalid_sequence"
  end
end
