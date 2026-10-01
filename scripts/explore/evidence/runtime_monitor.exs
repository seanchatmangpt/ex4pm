defmodule Explore.RuntimeMonitor do
  def valid?(events) do
    {_state,ok}=Enum.reduce(events,{:start,true},fn e,{s,ok}->
      next=case {s,e} do {:start,:parse}->:parsed; {:parsed,:admit}->:admitted; {:parsed,:refuse}->:done; {:admitted,:construct}->:constructed; {:constructed,:receipt_pending}->:pending; {:pending,:do}->:acted; {:acted,:receipt_outcome}->:done; _->:invalid end
      {next,ok and next != :invalid}
    end)
    ok
  end
end
true=Explore.RuntimeMonitor.valid?([:parse,:admit,:construct,:receipt_pending,:do,:receipt_outcome])
false=Explore.RuntimeMonitor.valid?([:parse,:admit,:construct,:do])
IO.inspect(%{candidate: :runtime_temporal_monitor, standing: :alive})
