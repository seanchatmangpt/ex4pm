defmodule Ex4pm.Reactor do
  @moduledoc """
  Canonical ex4pm workflow facade over `Ash.Reactor` and Reactor.

  `use Ex4pm.Reactor` delegates directly to `Ash.Reactor`; ex4pm does not own a
  competing DSL, planner, scheduler, retry loop, or saga executor. Dynamic POWL
  models are lowered with `Ex4pm.Runtime.compile/1` into the same Reactor runtime.

  Ash-aware workflows therefore retain the native Ash Reactor action surface,
  while ex4pm contributes process semantics, BRCE authority, receipts, replay,
  mining, and conformance around that single execution substrate.
  """

  defmacro __using__(opts) do
    quote do
      use Ash.Reactor, unquote(opts)
    end
  end

  def compile(model), do: Ex4pm.Runtime.compile(model)

  def execute(plan, authority, opts \\ []) do
    Ex4pm.Runtime.execute(plan, authority, opts)
  end
end
