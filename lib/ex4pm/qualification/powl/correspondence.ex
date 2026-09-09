defmodule Ex4pm.Qualification.Powl.Correspondence do
  @moduledoc "Executable two-way bounded POWL/Reactor correspondence court."

  alias Ex4pm.Core.Hash
  alias Ex4pm.Qualification.Powl.{BoundedUnfolder, Certificate, ReferenceOracle}
  alias Ex4pm.Runtime

  def check(model, bound) do
    oracle = ReferenceOracle.language(model, bound)
    compiled = BoundedUnfolder.language(model, bound)

    with true <- oracle == compiled || {:error, mismatch(oracle, compiled)},
         {:ok, fragments} <- verify_fragments(compiled) do
      {:ok, Certificate.new(bound, oracle, compiled, fragments)}
    else
      {:error, _} = error -> error
      false -> {:error, :correspondence_failed}
    end
  end

  def court do
    alias Ex4pmEngine.POWL

    a = POWL.activity("a", "A")
    b = POWL.activity("b", "B")
    c = POWL.activity("c", "C")
    redo = POWL.activity("r", "R")

    corpus = [
      a,
      POWL.sequence("seq", [a, b, c]),
      POWL.choice("choice", [a, b, c]),
      POWL.partial_order("po", [a, b, c], [{"a", "c"}]),
      POWL.loop("loop", POWL.sequence("body", [a, b]), redo),
      POWL.choice("nested", [POWL.sequence("s", [a, b]), POWL.partial_order("p", [b, c], [])]),
      POWL.choice_graph("graph", [a, b], [{"▷", "a"}, {"a", "□"}, {"▷", "b"}, {"b", "□"}])
    ]

    results = Enum.map(corpus, &check(&1, 2))

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      certificates = Enum.map(results, fn {:ok, certificate} -> certificate end)

      {:ok,
       %{
         models: length(corpus),
         traces: Enum.sum(Enum.map(certificates, & &1.trace_count)),
         certificates: certificates
       }}
    else
      {:error, results}
    end
  end

  def sabotage(model, bound, mutation) do
    oracle = ReferenceOracle.language(model, bound)
    compiled = BoundedUnfolder.language(model, bound)
    mutated = mutate(compiled, mutation)
    if oracle == mutated, do: {:error, :sabotage_survived}, else: :detected
  end

  defp verify_fragments(traces) do
    traces
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {trace, index}, {:ok, acc} ->
      case compile_trace(trace, index) do
        {:ok, fragment} -> {:cont, {:ok, [fragment | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, fragments} -> {:ok, Enum.reverse(fragments)}
      error -> error
    end
  end

  defp compile_trace([], index),
    do: {:ok, %{index: index, plan_hash: Hash.digest({:empty, index}), refined: true}}

  defp compile_trace(trace, index) do
    tasks =
      Enum.with_index(trace, 1)
      |> Enum.map(fn {label, i} ->
        %{id: "q#{index}-#{i}", label: label, intent: %{value: label}}
      end)

    ids = Enum.map(tasks, & &1.id)

    edges =
      ids |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [left, right] -> {left, right} end)

    with {:ok, model} <- Ex4pm.POWL.new(tasks, edges),
         {:ok, plan} <- Runtime.compile(model) do
      {:ok,
       %{
         index: index,
         plan_hash: Hash.digest(plan),
         refined: plan.model.edges == edges and plan.metadata.scheduler == Reactor.Executor
       }}
    end
  end

  defp mismatch(oracle, compiled) do
    %{extra: compiled -- oracle, missing: oracle -- compiled}
  end

  defp mutate(language, :extra_trace), do: Enum.uniq([["__illegal__"] | language])
  defp mutate([], :missing_trace), do: [["__missing__"]]
  defp mutate([_ | rest], :missing_trace), do: rest
  defp mutate([[a, b | rest] | tail], :wrong_order), do: [[b, a | rest] | tail]
  defp mutate(language, :wrong_order), do: Enum.uniq([["__wrong_order__"] | language])
  defp mutate([trace | rest], :duplicate_execution), do: [trace, trace | rest]

  defp mutate(language, :duplicate_execution),
    do: [["__duplicate__"], ["__duplicate__"] | language]

  defp mutate([_trace | rest], :lost_terminal), do: rest
  defp mutate(language, :lost_terminal), do: [["__lost__"] | language]
  defp mutate(language, :wrong_bound), do: Enum.uniq([["__bound__"] | language])
  defp mutate(language, _), do: Enum.uniq([["__mutation__"] | language])
end
