defmodule Ex4pm.Information.ReceiptMiddleware do
  @moduledoc """
  A `Reactor.Middleware` that bridges real Reactor step/run lifecycle events
  onto `:telemetry`, so BRCE-adjacent receipt consumers can observe a
  Reactor's execution without threading a receipt-writer through every step.

  This middleware never writes a receipt itself -- it only emits real
  `:telemetry.execute/3` events carrying the real Reactor event, step name,
  and context. Attaching a handler is the caller's job (see the Chicago test
  for the canonical pattern: `:telemetry.attach/4` sending to `self()`).
  """

  use Reactor.Middleware

  @complete [:ex4pm, :reactor, :complete]
  @error [:ex4pm, :reactor, :error]
  @step_start [:ex4pm, :reactor, :step, :start]
  @step_event [:ex4pm, :reactor, :step, :event]

  @impl true
  def init(context), do: {:ok, context}

  @impl true
  def complete(result, context) do
    :telemetry.execute(@complete, %{}, %{result: result, context: context})
    {:ok, result}
  end

  @impl true
  def error(errors, context) do
    :telemetry.execute(@error, %{}, %{errors: errors, context: context})
    :ok
  end

  @impl true
  def event({:run_start, _arguments} = event, step, context) do
    :telemetry.execute(@step_start, %{}, %{event: event, step: step.name, context: context})
    :ok
  end

  def event(event, step, context) do
    :telemetry.execute(@step_event, %{}, %{event: event, step: step.name, context: context})
    :ok
  end
end
