defmodule Ex4pmWeb.HealthControllerTest do
  use Ex4pmWeb.ConnCase, async: true

  test "GET /health returns ok standing", %{conn: conn} do
    conn = get(conn, ~p"/health")
    assert json_response(conn, 200)["status"] == "ok"
    assert json_response(conn, 200)["standing"] == "alive"
  end

  test "GET /health/ready returns service readiness", %{conn: conn} do
    conn = get(conn, ~p"/health/ready")
    assert json_response(conn, 200)["ready"] == true
  end
end
