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
  def complete(result, context) do
    target = Map.get(context, :test_pid, self())

    send(
      target,
      {:ocel_step_event,
       %{
         activity: reactor_identity(context),
         lifecycle: :complete,
         timestamp: DateTime.utc_now(),
         type: :forward,
         result: result
       }}
    )

    {:ok, result}
  end

  @impl true
  def error(errors, context) do
    target = Map.get(context, :test_pid, self())

    send(
      target,
      {:ocel_step_event,
       %{
         activity: reactor_identity(context),
         lifecycle: :error,
         timestamp: DateTime.utc_now(),
         type: :forward,
         errors: List.wrap(errors)
       }}
    )

    :ok
  end

  @impl true
  def event({:run_start, _args}, step, context) do
    target = Map.get(context, :test_pid, self())

    send(
      target,
      {:ocel_step_event,
       %{
         activity: to_string(step.name),
         lifecycle: :start,
         timestamp: DateTime.utc_now(),
         type: :forward
       }}
    )

    :ok
  end

  @impl true
  def event(:undo_start, step, context) do
    target = Map.get(context, :test_pid, self())

    send(
      target,
      {:ocel_step_event,
       %{
         activity: "undo_" <> to_string(step.name),
         lifecycle: :undo,
         timestamp: DateTime.utc_now(),
         type: :compensation
       }}
    )

    :ok
  end

  def event({:undo_start, _res}, step, context) do
    target = Map.get(context, :test_pid, self())

    send(
      target,
      {:ocel_step_event,
       %{
         activity: "undo_" <> to_string(step.name),
         lifecycle: :undo,
         timestamp: DateTime.utc_now(),
         type: :compensation
       }}
    )

    :ok
  end

  def event({:run_complete, result}, step, context) do
    target = Map.get(context, :test_pid, self())

    send(
      target,
      {:ocel_step_event,
       %{
         activity: to_string(step.name),
         lifecycle: :complete,
         timestamp: DateTime.utc_now(),
         type: :forward,
         result: result
       }}
    )

    :ok
  end

  def event({:run_error, errors}, step, context) do
    target = Map.get(context, :test_pid, self())

    send(
      target,
      {:ocel_step_event,
       %{
         activity: to_string(step.name),
         lifecycle: :error,
         timestamp: DateTime.utc_now(),
         type: :forward,
         errors: List.wrap(errors)
       }}
    )

    :ok
  end

  def event(unmodeled_event, step, context) do
    target = Map.get(context, :test_pid, self())

    send(
      target,
      {:ocel_step_event,
       %{
         activity: "unmodeled_" <> to_string(step.name),
         lifecycle: :unmodeled,
         timestamp: DateTime.utc_now(),
         type: :unmodeled,
         raw_event: unmodeled_event
       }}
    )

    :ok
  end

  defp reactor_identity(context) do
    case Map.get(context, :id) do
      nil -> "reactor"
      id -> to_string(id)
    end
  end
end
