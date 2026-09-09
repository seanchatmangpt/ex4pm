defmodule Ex4pm.Information.ReceiptMiddlewareTest do
  @moduledoc """
  Real, no-mock proof that `Ex4pm.Information.ReceiptMiddleware` bridges
  actual Reactor step/run lifecycle events onto `:telemetry` -- a real
  `Reactor.run/2` execution, a real `:telemetry.attach/4` handler sending to
  `self()`, state-based assertions on the received event payloads.
  """
  use ExUnit.Case, async: true

  defmodule DoubleStep do
    @moduledoc false
    use Reactor.Step

    @impl true
    def run(%{value: value}, _context, _options), do: {:ok, value * 2}
  end

  defmodule SampleReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware(Ex4pm.Information.ReceiptMiddleware)
    end

    input(:value)

    step :double, DoubleStep do
      argument(:value, input(:value))
    end

    return(:double)
  end

  setup do
    ref = make_ref()
    test_pid = self()

    handler = fn event, measurements, metadata, _config ->
      send(test_pid, {:telemetry_event, ref, event, measurements, metadata})
    end

    handler_id = "receipt-middleware-test-#{inspect(ref)}"

    :telemetry.attach_many(
      handler_id,
      [
        [:ex4pm, :reactor, :complete],
        [:ex4pm, :reactor, :error],
        [:ex4pm, :reactor, :step, :start],
        [:ex4pm, :reactor, :step, :event]
      ],
      handler,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    {:ok, ref: ref}
  end

  test "a real successful Reactor run emits a real :complete telemetry event with the real result",
       %{ref: ref} do
    assert {:ok, 8} = Reactor.run(SampleReactor, %{value: 4})

    assert_received {:telemetry_event, ^ref, [:ex4pm, :reactor, :complete], %{},
                     %{result: 8, context: context}}

    assert is_map(context)
  end

  test "a real Reactor run emits a real step-start telemetry event naming the real step", %{
    ref: ref
  } do
    assert {:ok, _} = Reactor.run(SampleReactor, %{value: 1})

    assert_received {:telemetry_event, ^ref, [:ex4pm, :reactor, :step, :start], %{},
                     %{step: :double, event: {:run_start, arguments}}}

    assert %{value: 1} = arguments
  end
end
