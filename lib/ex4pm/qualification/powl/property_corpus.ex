defmodule Ex4pm.Qualification.Powl.PropertyCorpus do
  @moduledoc """
  Deterministic generated POWL 2.0 differential corpus.

  The generator is deliberately seed-free: case identity determines syntax,
  so a failing model is exactly replayable from its integer case id.
  """

  alias Ex4pm.Qualification.Powl.{BoundedUnfolder, Correspondence, ReferenceOracle}
  alias Ex4pmEngine.POWL

  @default_cases 2_048

  def run(count \\ @default_cases) when is_integer(count) and count > 0 do
    0..(count - 1)
    |> Enum.reduce_while({:ok, %{cases: 0, traces: 0, reactor_samples: 0}}, fn id, {:ok, acc} ->
      {model, bound} = case_model(id)
      oracle = ReferenceOracle.language(model, bound)
      compiled = BoundedUnfolder.language(model, bound)

      cond do
        oracle != compiled ->
          {:halt,
           {:error,
            %{
              case_id: id,
              bound: bound,
              extra: compiled -- oracle,
              missing: oracle -- compiled
            }}}

        rem(id, 32) == 0 ->
          case Correspondence.check(model, bound) do
            {:ok, certificate} when certificate.soundness and certificate.completeness ->
              {:cont,
               {:ok,
                %{
                  cases: acc.cases + 1,
                  traces: acc.traces + length(oracle),
                  reactor_samples: acc.reactor_samples + 1
                }}}

            other ->
              {:halt, {:error, %{case_id: id, reactor_refinement: other}}}
          end

        true ->
          {:cont,
           {:ok,
            %{
              cases: acc.cases + 1,
              traces: acc.traces + length(oracle),
              reactor_samples: acc.reactor_samples
            }}}
      end
    end)
  end

  def invalid_identity_court do
    duplicate = [
      %{id: "same", label: "A"},
      %{id: "same", label: "B"}
    ]

    cycle_tasks = [%{id: "a"}, %{id: "b"}]

    checks = [
      match?({:error, %{code: :duplicate_task_id}}, Ex4pm.POWL.new(duplicate, [])),
      match?(
        {:error, %{code: :cyclic_powl}},
        Ex4pm.POWL.new(cycle_tasks, [{"a", "b"}, {"b", "a"}])
      ),
      match?({:error, %{code: :self_cycle}}, Ex4pm.POWL.new(cycle_tasks, [{"a", "a"}])),
      match?({:error, %{code: :unknown_task}}, Ex4pm.POWL.new(cycle_tasks, [{"a", "missing"}]))
    ]

    if Enum.all?(checks), do: {:ok, %{invalid_cases: length(checks)}}, else: {:error, checks}
  end

  def case_model(id) when is_integer(id) and id >= 0 do
    a = POWL.activity("a#{id}", "A#{rem(id, 7)}")
    b = POWL.activity("b#{id}", "B#{rem(id, 11)}")
    c = POWL.activity("c#{id}", "C#{rem(id, 13)}")
    r = POWL.activity("r#{id}", "R#{rem(id, 5)}")
    bound = rem(div(id, 5), 3)

    model =
      case rem(id, 8) do
        0 ->
          POWL.sequence("seq#{id}", [a, b, c])

        1 ->
          POWL.choice("choice#{id}", [a, b, c])

        2 ->
          POWL.partial_order("po#{id}", [a, b, c], [{a.id, c.id}])

        3 ->
          POWL.partial_order("parallel#{id}", [a, b, c], [])

        4 ->
          POWL.loop("loop#{id}", POWL.sequence("body#{id}", [a, b]), r)

        5 ->
          POWL.choice("nested#{id}", [
            POWL.sequence("s#{id}", [a, b]),
            POWL.partial_order("p#{id}", [b, c], [])
          ])

        6 ->
          choice_graph(id, a, b, c)

        7 ->
          POWL.sequence("mixed#{id}", [
            POWL.choice("x#{id}", [a, b]),
            POWL.partial_order("y#{id}", [b, c], [])
          ])
      end

    {model, bound}
  end

  defp choice_graph(id, a, b, c) do
    edges =
      if rem(id, 2) == 0 do
        [{"▷", a.id}, {a.id, "□"}, {"▷", b.id}, {b.id, c.id}, {c.id, "□"}]
      else
        [{"▷", a.id}, {a.id, b.id}, {b.id, "□"}, {"▷", c.id}, {c.id, "□"}]
      end

    POWL.choice_graph("graph#{id}", [a, b, c], edges)
  end
end
