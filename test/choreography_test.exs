defmodule Ex4pm.Engine.ChoreographyTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Choreography
  alias Ex4pmEngine.Choreography.{AgentNet, Channel}

  test "formally verifies sound communicating multi-agent choreography" do
    # Agent 1 (Customer): p_in -> [order] -> p_wait -> [receive_invoice] -> p_out
    agent1_net = %{
      transitions: %{
        order: %{inputs: ["p_in"], outputs: ["p_wait"], label: "PlaceOrder"},
        recv_inv: %{inputs: ["p_wait"], outputs: ["p_out"], label: "ReceiveInvoice"}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    agent1 = %AgentNet{
      id: "customer",
      net: agent1_net,
      sends: %{order: "order_channel"},
      receives: %{recv_inv: "invoice_channel"}
    }

    # Agent 2 (Merchant): p_in -> [receive_order] -> p_process -> [send_invoice] -> p_out
    agent2_net = %{
      transitions: %{
        recv_order: %{inputs: ["p_in"], outputs: ["p_process"], label: "ReceiveOrder"},
        send_inv: %{inputs: ["p_process"], outputs: ["p_out"], label: "SendInvoice"}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    agent2 = %AgentNet{
      id: "merchant",
      net: agent2_net,
      sends: %{send_inv: "invoice_channel"},
      receives: %{recv_order: "order_channel"}
    }

    channels = [
      %Channel{name: "order_channel", source_agent: "customer", target_agent: "merchant"},
      %Channel{name: "invoice_channel", source_agent: "merchant", target_agent: "customer"}
    ]

    report = Choreography.verify_choreography([agent1, agent2], channels)
    assert report.sound? == true
    assert report.orphan_messages? == false
    assert report.deadlocks == []
  end

  test "detects message deadlock when both agents wait for messages from each other" do
    # Mutually blocking deadlocked choreography
    agent1_net = %{
      transitions: %{
        recv_first: %{inputs: ["p_in"], outputs: ["p_out"], label: "WaitA"}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    agent1 = %AgentNet{
      id: "agent_a",
      net: agent1_net,
      receives: %{recv_first: "chan_b_to_a"}
    }

    agent2_net = %{
      transitions: %{
        recv_first: %{inputs: ["p_in"], outputs: ["p_out"], label: "WaitB"}
      },
      initial_marking: ["p_in"],
      final_marking: ["p_out"]
    }

    agent2 = %AgentNet{
      id: "agent_b",
      net: agent2_net,
      receives: %{recv_first: "chan_a_to_b"}
    }

    channels = [
      %Channel{name: "chan_b_to_a", source_agent: "agent_b", target_agent: "agent_a"},
      %Channel{name: "chan_a_to_b", source_agent: "agent_a", target_agent: "agent_b"}
    ]

    report = Choreography.verify_choreography([agent1, agent2], channels)
    assert report.sound? == false
    assert length(report.deadlocks) > 0
  end
end
