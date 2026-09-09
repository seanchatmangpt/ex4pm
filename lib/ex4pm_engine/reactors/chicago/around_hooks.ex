# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.Chicago.AroundHooks do
  @moduledoc """
  Around-hooks providing transactional execution boundaries and BRCE receipt
  enforcement around Reactor step executions.
  """

  alias Ex4pm.Core.Hash
  alias Ex4pm.Evidence.BRCE

  @doc """
  Wraps reactor step execution inside a BRCE evidence envelope.
  Emits a pending receipt before execution and an outcome receipt upon completion.
  """
  def with_brce_boundary(arguments, context, _options, callback) do
    subject = Map.get(arguments, :subject, arguments)
    subject_hash = Hash.digest(subject)
    operation = Map.get(arguments, :operation, :reactor_around_boundary)
    authority = Map.get(context, :authority, %{id: "chicago_reactor", capabilities: [:do]})
    store = Map.get(context, :store, Ex4pm.Evidence.Store)

    BRCE.execute(
      subject_hash,
      operation,
      authority,
      fn ->
        callback.(arguments, context)
      end,
      store: store,
      metadata: %{
        around_hook: :with_brce_boundary,
        timestamp: DateTime.utc_now()
      }
    )
  end

  @doc """
  Telemetry and latency measurement around hook.
  """
  def with_latency_audit(arguments, context, _options, callback) do
    start_time = System.monotonic_time(:microsecond)
    result = callback.(arguments, context)
    duration_us = System.monotonic_time(:microsecond) - start_time

    case result do
      {:ok, value} ->
        {:ok, Map.put(value, :execution_duration_us, duration_us)}

      other ->
        other
    end
  end
end
