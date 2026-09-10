# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.Middlewares.OCELEventMiddlewareTest do
  @moduledoc """
  Chicago-style (real collaborators, state-based assertions) test for
  `Ex4pmEngine.Reactors.Middlewares.OCELEventMiddleware`.

  Runs a real `Reactor` (no mocks) with the middleware attached, forces one
  real successful completion and one real failure path, and asserts on the
  real `{:ocel_step_event, ...}` messages actually sent to this test process.
  """
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Reactors.Middlewares.OCELEventMiddleware

  defmodule SucceedingReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware(OCELEventMiddleware)
    end

    input(:value)

    step :double do
      argument(:value, input(:value))
      run(fn %{value: value}, _context -> {:ok, value * 2} end)
    end
  end

  defmodule FailingReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware(OCELEventMiddleware)
    end

    input(:value)

    step :explode do
      argument(:value, input(:value))
      run(fn %{value: _value}, _context -> {:error, :boom} end)
    end
  end

  describe "complete/2" do
    test "emits a real OCEL-shaped completion event on real reactor success" do
      assert {:ok, 84} =
               Reactor.run(SucceedingReactor, %{value: 42}, %{test_pid: self()})

      assert_receive {:ocel_step_event,
                       %{
                         lifecycle: :complete,
                         type: :forward,
                         result: 84,
                         timestamp: %DateTime{}
                       } = complete_event}

      assert is_binary(complete_event.activity)
    end

    test "also emits a real step-level run_complete event for the succeeding step" do
      assert {:ok, 10} =
               Reactor.run(SucceedingReactor, %{value: 5}, %{test_pid: self()})

      assert_receive {:ocel_step_event,
                       %{
                         activity: "double",
                         lifecycle: :complete,
                         type: :forward,
                         result: 10,
                         timestamp: %DateTime{}
                       }}
    end
  end

  describe "error/2" do
    test "emits a real OCEL-shaped error event on real reactor failure" do
      assert {:error, _reason} =
               Reactor.run(FailingReactor, %{value: 42}, %{test_pid: self()})

      assert_receive {:ocel_step_event,
                       %{
                         lifecycle: :error,
                         type: :forward,
                         errors: errors,
                         timestamp: %DateTime{}
                       } = error_event}

      assert is_list(errors)
      assert errors != []
      assert is_binary(error_event.activity)
    end

    test "also emits a real step-level run_error event for the failing step" do
      assert {:error, _reason} =
               Reactor.run(FailingReactor, %{value: 1}, %{test_pid: self()})

      assert_receive {:ocel_step_event,
                       %{
                         activity: "explode",
                         lifecycle: :error,
                         type: :forward,
                         errors: errors,
                         timestamp: %DateTime{}
                       }}

      assert is_list(errors)
      assert errors != []
    end
  end

  describe "event/3 run_start / undo_start" do
    test "still emits real start events for the successful path" do
      assert {:ok, _} = Reactor.run(SucceedingReactor, %{value: 1}, %{test_pid: self()})

      assert_receive {:ocel_step_event,
                       %{
                         activity: "double",
                         lifecycle: :start,
                         type: :forward,
                         timestamp: %DateTime{}
                       }}
    end
  end

  describe "unmodeled event catch-all" do
    test "the catch-all clause emits a real, distinguishable unmodeled-event message" do
      step = %Reactor.Step{name: :some_step, impl: __MODULE__}

      assert :ok =
               OCELEventMiddleware.event(:some_unmodeled_event, step, %{test_pid: self()})

      assert_receive {:ocel_step_event,
                       %{
                         activity: "unmodeled_some_step",
                         lifecycle: :unmodeled,
                         type: :unmodeled,
                         raw_event: :some_unmodeled_event,
                         timestamp: %DateTime{}
                       }}
    end
  end
end
