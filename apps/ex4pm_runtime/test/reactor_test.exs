defmodule Ex4pm.ReactorTest do
  use ExUnit.Case, async: true

  defmodule EchoStep do
    use Reactor.Step

    @impl true
    def run(%{value: value}, _context, _options), do: {:ok, value}
  end

  defmodule WrappedAshReactor do
    use Ex4pm.Reactor

    input(:value)

    step :echo, Ex4pm.ReactorTest.EchoStep do
      argument(:value, input(:value))
    end

    return(:echo)
  end

  test "Ex4pm.Reactor is an Ash.Reactor extension over the canonical Reactor runtime" do
    assert Spark.Dsl.is?(WrappedAshReactor, Reactor)
    assert {:ok, "canonical"} = Reactor.run(WrappedAshReactor, %{value: "canonical"})
  end
end
