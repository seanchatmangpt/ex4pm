defmodule Ex4pm.Runtime.PowlExecutorTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Runtime.PowlExecutor

  # A tiny POWL/Petri-net: p1 --t1--> p2 --t2--> p3
  defp transitions do
    %{
      t1: %{inputs: [:p1], outputs: [:p2]},
      t2: %{inputs: [:p2], outputs: [:p3]},
      t_needs_two: %{inputs: [:p1, :p2], outputs: [:p3]}
    }
  end

  test "start_link initializes the real process with the given marking" do
    {:ok, pid} = PowlExecutor.start_link(%{p1: 1, p2: 0, p3: 0}, transitions())

    # :state_functions callback_mode reports state as {state_name, data} --
    # this is real :gen_statem/GenStateMachine behavior, not a stub.
    assert {:marking, %Ex4pm.Runtime.PowlExecutor.Data{marking: %{p1: 1, p2: 0, p3: 0}}} =
             :sys.get_state(pid)
  end

  test "legal fire consumes input tokens and produces output tokens" do
    {:ok, pid} = PowlExecutor.start_link(%{p1: 1, p2: 0, p3: 0}, transitions())

    assert {:ok, %{p1: 0, p2: 1, p3: 0}} = PowlExecutor.fire(pid, :t1)

    {:marking, %Ex4pm.Runtime.PowlExecutor.Data{marking: marking}} = :sys.get_state(pid)
    assert marking == %{p1: 0, p2: 1, p3: 0}
  end

  test "chained legal fires move the token through the whole net" do
    {:ok, pid} = PowlExecutor.start_link(%{p1: 1, p2: 0, p3: 0}, transitions())

    assert {:ok, _} = PowlExecutor.fire(pid, :t1)
    assert {:ok, %{p1: 0, p2: 0, p3: 1}} = PowlExecutor.fire(pid, :t2)
  end

  test "illegal fire (insufficient tokens) is refused and marking is unchanged" do
    {:ok, pid} = PowlExecutor.start_link(%{p1: 0, p2: 0, p3: 0}, transitions())

    before = :sys.get_state(pid)

    assert {:error, :insufficient_tokens} = PowlExecutor.fire(pid, :t1)

    assert :sys.get_state(pid) == before
    assert PowlExecutor.marking(pid) == %{p1: 0, p2: 0, p3: 0}
  end

  test "fire requiring multiple input places refuses unless all have tokens" do
    {:ok, pid} = PowlExecutor.start_link(%{p1: 1, p2: 0, p3: 0}, transitions())

    # p2 has no token yet -- t_needs_two requires both p1 and p2.
    assert {:error, :insufficient_tokens} = PowlExecutor.fire(pid, :t_needs_two)
    assert PowlExecutor.marking(pid) == %{p1: 1, p2: 0, p3: 0}

    # Firing t1 moves the only token from p1 to p2, so p1 and p2 are still
    # never simultaneously occupied on this net -- start a fresh process with
    # both places genuinely marked to exercise the real "all inputs present"
    # path.
    {:ok, pid2} = PowlExecutor.start_link(%{p1: 1, p2: 1, p3: 0}, transitions())
    assert {:ok, %{p1: 0, p2: 0, p3: 1}} = PowlExecutor.fire(pid2, :t_needs_two)
  end

  test "firing an unknown transition is refused with an unchanged marking" do
    {:ok, pid} = PowlExecutor.start_link(%{p1: 1}, transitions())

    assert {:error, :unknown_transition} = PowlExecutor.fire(pid, :does_not_exist)
    assert PowlExecutor.marking(pid) == %{p1: 1}
  end
end
