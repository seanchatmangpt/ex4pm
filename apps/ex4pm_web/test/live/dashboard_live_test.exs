# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmWeb.DashboardLiveTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint Ex4pmWeb.Endpoint

  test "mounts /dashboard successfully with reactive DAGs and Conformance metrics" do
    conn = build_conn()
    {:ok, view, html} = live(conn, "/dashboard")

    assert html =~ "ex4pm Process Intelligence Control Plane"
    assert html =~ "Living Reactor Execution Graph"
    assert html =~ "Distributed Erlang Cluster Mesh"
    assert html =~ "Cryptographic BRCE Receipt Ledger"
    assert html =~ "Run 12-Stage Book Validation"

    # Test interactive event triggering on the dashboard
    rendered = render_click(view, "run_book_validation")
    assert rendered =~ "Last Exec: book_validation"
  end
end
