defmodule Ex4pm.Stream.PipelineConcurrencyTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Event
  alias Ex4pm.Stream.Pipeline

  test "Broadway pipeline processes 500 events concurrently with backpressure" do
    test_pid = self()

    sink = fn %Event{} = event ->
      send(test_pid, {:processed, event.id})
    end

    raw_events =
      for i <- 1..500 do
        %Event{
          id: "stream-ev-#{i}",
          activity: "action.step",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          attributes: %{"index" => i}
        }
      end

    {:ok, _pid} =
      Pipeline.start_link(
        name: :concurrency_stream_pipeline,
        events: raw_events,
        sink: sink,
        producer_concurrency: 1,
        processor_concurrency: 4
      )

    # Collect all messages with timeout
    processed =
      Enum.reduce(1..500, MapSet.new(), fn _i, acc ->
        receive do
          {:processed, id} -> MapSet.put(acc, id)
        after
          5000 -> acc
        end
      end)

    assert MapSet.size(processed) == 500
  end
end
