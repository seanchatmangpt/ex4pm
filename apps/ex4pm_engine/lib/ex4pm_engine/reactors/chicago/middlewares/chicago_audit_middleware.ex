# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.Chicago.Middlewares.ChicagoAuditMiddleware do
  @moduledoc """
  Audits Reactor lifecycle events, recording step transitions, durations, and receipts
  into process telemetry and caller mailbox.
  """
  use Reactor.Middleware
  require Logger

  @impl true
  def init(context) do
    {:ok, Map.put(context, :audit_started_at, DateTime.utc_now())}
  end

  @impl true
  def complete(result, context) do
    if caller = Map.get(context, :test_pid) do
      send(caller, {:reactor_completed, result})
    end

    {:ok, result}
  end

  @impl true
  def error(errors, context) do
    if caller = Map.get(context, :test_pid) do
      send(caller, {:reactor_failed, errors})
    end

    :ok
  end

  @impl true
  def event({:run_start, arguments}, step, context) do
    if caller = Map.get(context, :test_pid) do
      send(caller, {:step_started, step.name, arguments})
    end

    :ok
  end

  def event({:run_complete, result}, step, context) do
    if caller = Map.get(context, :test_pid) do
      send(caller, {:step_completed, step.name, result})
    end

    :ok
  end

  def event({:undo_start, _val}, step, context) do
    if caller = Map.get(context, :test_pid) do
      send(caller, {:step_undoing, step.name})
    end

    :ok
  end

  def event({:undo_complete, _val}, step, context) do
    if caller = Map.get(context, :test_pid) do
      send(caller, {:step_undone, step.name})
    end

    :ok
  end

  def event(_other, _step, _context), do: :ok
end
