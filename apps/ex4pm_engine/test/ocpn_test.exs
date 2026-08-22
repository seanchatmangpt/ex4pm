defmodule Ex4pmEngine.OCPNTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.OCPN

  describe "Object-Centric Petri Net (OCPN)" do
    test "constructs OCPN with typed places, multi-cast transitions, and verifies token conservation" do
      net =
        OCPN.new("order_handling", ["Order", "Item"])
        |> OCPN.add_place("p_ord_init", "Order", initial: true)
        |> OCPN.add_place("p_ord_paid", "Order")
        |> OCPN.add_place("p_ord_closed", "Order", terminal: true)
        |> OCPN.add_place("p_item_init", "Item", initial: true)
        |> OCPN.add_place("p_item_packed", "Item", terminal: true)
        |> OCPN.add_transition("t_create_order", "Create Order", ["Order", "Item"])
        |> OCPN.add_transition("t_pay", "Pay Order", ["Order"])
        |> OCPN.add_arc("p_ord_init", "t_create_order", "Order")
        |> OCPN.add_arc("t_create_order", "p_ord_paid", "Order")
        |> OCPN.add_arc("p_item_init", "t_create_order", "Item")
        |> OCPN.add_arc("t_create_order", "p_item_packed", "Item")
        |> OCPN.add_arc("p_ord_paid", "t_pay", "Order")
        |> OCPN.add_arc("t_pay", "p_ord_closed", "Order")

      assert {:ok, :conserved} = OCPN.verify_token_conservation(net)

      assert {:ok, order_sound} = OCPN.project_and_verify_soundness(net, "Order")
      assert order_sound.sound? == true
      assert order_sound.place_count == 3

      assert {:ok, item_sound} = OCPN.project_and_verify_soundness(net, "Item")
      assert item_sound.sound? == true
      assert item_sound.place_count == 2
    end
  end
end
