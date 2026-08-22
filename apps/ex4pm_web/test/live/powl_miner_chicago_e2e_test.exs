# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmWeb.PowlMinerChicagoE2ETest do
  use Ex4pmWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "Chicago-Style E2E: Paper Author Discovery & Export Workflow on /powl-miner" do
    test "uploads real Order-to-Delivery CSV log, discovers model, switches views, and validates export links", %{conn: conn} do
      {:ok, view, html} = live(conn, "/powl-miner")

      assert html =~ "POWL Miner 2.0"
      assert html =~ "Discovery Configuration"

      # 1. Prepare CSV content representing BPM 2025 Order-to-Delivery case
      csv_content = """
      case_id,activity
      case_1,CheckCredit
      case_1,ExpressShip
      case_1,Deliver
      case_2,CheckCredit
      case_2,ExpressShip
      case_2,AddInsurance
      case_2,Deliver
      case_3,CheckCredit
      case_3,RegularShip
      case_3,Deliver
      """

      # 2. Upload file via LiveView upload channel
      log_upload =
        file_input(view, "#upload-form", :event_log, [
          %{
            name: "order_to_delivery.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(log_upload, "order_to_delivery.csv")

      # 3. Adjust threshold
      render_change(view, :validate_form, %{"threshold" => "0.1"})

      # 4. Submit form
      html_discovered = render_submit(view, :run_discovery, %{})

      # 5. Assert model elements and formal guarantees
      assert html_discovered =~ "CheckCredit"
      assert html_discovered =~ "ExpressShip"
      assert html_discovered =~ "Deliver"
      assert html_discovered =~ "100% Guaranteed"
      assert html_discovered =~ "1-Safe Sound"

      # 6. Verify SVG contains math delimiters ▷ and □
      assert html_discovered =~ "▷"
      assert html_discovered =~ "□"

      # 7. Switch view to Petri Net
      html_petri = render_click(view, :switch_view, %{"view" => "petri"})
      assert html_petri =~ "Petri Net (Places:"

      # 8. Switch view to BPMN
      html_bpmn = render_click(view, :switch_view, %{"view" => "bpmn"})
      assert html_bpmn =~ "CheckCredit"

      # 9. Verify download links are populated with valid data URIs
      assert html_discovered =~ "download=\"process_model.bpmn\""
      assert html_discovered =~ "download=\"process_model.pnml\""
      assert html_discovered =~ "data:application/xml;charset=utf-8,"
    end
  end
end
