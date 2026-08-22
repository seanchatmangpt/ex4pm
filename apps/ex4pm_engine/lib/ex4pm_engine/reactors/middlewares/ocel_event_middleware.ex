# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.Middlewares.OCELEventMiddleware do
  @moduledoc """
  Reactor Middleware capturing real-time saga lifecycle transitions into standard IEEE OCEL 2.0 events.
  Intercepts forward execution and backward LIFO compensation/undo events.
  """
  use Reactor.Middleware

  @impl true
  def init(context) do
    {:ok, Map.put_new(context, :ocel_events, [])}
  end

  @impl true
  def complete(result, _context) do
    {:ok, result}
  end

  @impl true
  def error(_errors, _context) do
    :ok
  end

  @impl true
  def event({:run_start, _args}, step, context) do
    target = Map.get(context, :test_pid, self())
    send(target, {:ocel_step_event, %{
      activity: to_string(step.name),
      lifecycle: :start,
      timestamp: DateTime.utc_now(),
      type: :forward
    }})
    :ok
  end

  @impl true
  def event(:undo_start, step, context) do
    target = Map.get(context, :test_pid, self())
    send(target, {:ocel_step_event, %{
      activity: "undo_" <> to_string(step.name),
      lifecycle: :undo,
      timestamp: DateTime.utc_now(),
      type: :compensation
    }})
    :ok
  end

  def event({:undo_start, _res}, step, context) do
    target = Map.get(context, :test_pid, self())
    send(target, {:ocel_step_event, %{
      activity: "undo_" <> to_string(step.name),
      lifecycle: :undo,
      timestamp: DateTime.utc_now(),
      type: :compensation
    }})
    :ok
  end

  def event(_event, _step, _context), do: :ok
end
