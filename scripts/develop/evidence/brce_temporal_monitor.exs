defmodule Ex4pm.Develop.Evidence.BRCETemporalMonitor do
  def verify(events) do
    Enum.reduce_while(events,{false,false},fn event,{pending,done}->
      case event do
        :pending_receipt -> {:cont,{true,done}}
        :do when pending and not done -> {:cont,{pending,true}}
        :do -> {:halt,{:refused,:unreceipted_do}}
        :outcome_receipt when done -> {:cont,{false,false}}
        :outcome_receipt -> {:halt,{:refused,:orphan_outcome_receipt}}
        _ -> {:cont,{pending,done}}
      end
    end)
    |> case do
      {:refused,_}=r -> r
      {false,false} -> :ok
      _ -> {:refused,:unterminated_actuation}
    end
  end
end
