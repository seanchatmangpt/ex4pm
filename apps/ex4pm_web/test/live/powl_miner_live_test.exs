# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmWeb.PowlMinerLiveTest do
  use Ex4pmWeb.ConnCase
  import Phoenix.LiveViewTest

  test "renders the POWL 2.0 Miner LiveView and switches views", %{conn: conn} do
    {:ok, view, html} = live(conn, "/powl-miner")

    assert html =~ "POWL Miner 2.0"
    assert html =~ "Process Discovery with the"
    assert html =~ "POWL 2.0 ($G = (N, E)$)"

    # Switch view to Petri Net
    html_petri = render_click(view, :switch_view, %{"view" => "petri"})
    assert html_petri =~ "Petri Net"

    # Switch view to BPMN
    html_bpmn = render_click(view, :switch_view, %{"view" => "bpmn"})
    assert html_bpmn =~ "BPMN 2.0"
  end

  test "triggers discovery on default Order-to-Delivery example", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/powl-miner")

    # Submit form without upload to run default example
    html_result = render_submit(view, :run_discovery, %{})

    assert html_result =~ "CheckCredit"
    assert html_result =~ "ExpressShip"
    assert html_result =~ "Deliver"
    assert html_result =~ "Denoted Language Multisets"
    assert html_result =~ "process_model.bpmn"
    assert html_result =~ "process_model.pnml"
  end
end
