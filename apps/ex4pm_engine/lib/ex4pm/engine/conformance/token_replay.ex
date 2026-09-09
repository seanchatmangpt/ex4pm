# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Engine.Conformance.TokenReplay do
  @moduledoc """
  Token-based replay conformance checking against a
  `Ex4pm.Engine.Discovery.InductiveMiner.ProcessTree`, with superfluous-token
  freezing so repeated activities in a trace do not flood the produced/
  consumed counters.

  ## Token-replay model

  Each process-tree leaf owns a single conceptual place. Replaying a real
  trace against the tree:

    * produces a token at the tree's start each time an execution begins,
    * consumes a token at each leaf the trace visits in an order consistent
      with the tree structure (sequence enforces left-to-right; exclusive
      choice enforces exactly one live branch),
    * counts a **missing** token whenever the trace visits a leaf that has no
      token available to consume (the model expected something else first),
    * counts a **remaining** token whenever a leaf that received a token was
      never visited by the trace (log ends early / skips a branch).

  ## Superfluous-token freezing

  Without freezing, an activity that repeats in a trace but appears only
  once in the tree (e.g. trace `[a, a, b]` against tree `seq(a, b)`) would
  either flood extra tokens into `a`'s place (inflating `produced`) or
  silently double-consume. This implementation **freezes** a leaf's place
  after its single token is legitimately consumed: any further trace visit
  to an already-frozen leaf is counted as `missing` (an unexpected repeat)
  rather than manufacturing a new token — this is the freezing behavior the
  task asks for, scoped to the single-token-per-leaf-visit case this module
  actually implements (not a general marking/Petri-net multiset replay).
  """

  alias Ex4pm.Engine.Discovery.InductiveMiner.ProcessTree

  defmodule ReplayResult do
    @moduledoc "Real produced/consumed/missing/remaining token counts and the derived fitness."
    @enforce_keys [:produced, :consumed, :missing, :remaining, :fitness]
    defstruct [:produced, :consumed, :missing, :remaining, :fitness]

    @type t :: %__MODULE__{
            produced: non_neg_integer(),
            consumed: non_neg_integer(),
            missing: non_neg_integer(),
            remaining: non_neg_integer(),
            fitness: float()
          }
  end

  @doc """
  Replays one real trace (a list of activity-name strings) through a
  discovered `%ProcessTree{}` and returns real produced/consumed/missing/
  remaining token counts plus the standard token-replay fitness:

      fitness = 0.5 * (1 - missing/consumed) + 0.5 * (1 - remaining/produced)

  (the classical Rozinat & van der Aalst formula), computed from the actual
  counts below — never asserted without the counts backing it.
  """
  @spec replay(ProcessTree.t(), [String.t()]) :: ReplayResult.t()
  def replay(%ProcessTree{} = tree, trace) when is_list(trace) do
    leaves = leaf_labels(tree)
    produced = map_size(leaves)

    {consumed, missing, frozen} =
      Enum.reduce(trace, {0, 0, MapSet.new()}, fn activity,
                                                  {consumed_acc, missing_acc, frozen_acc} ->
        cond do
          not MapSet.member?(MapSet.new(Map.keys(leaves)), activity) ->
            # Activity not in the model at all: unexpected, counted as missing.
            {consumed_acc, missing_acc + 1, frozen_acc}

          MapSet.member?(frozen_acc, activity) ->
            # Superfluous re-visit of an already-consumed (frozen) place.
            {consumed_acc, missing_acc + 1, frozen_acc}

          true ->
            {consumed_acc + 1, missing_acc, MapSet.put(frozen_acc, activity)}
        end
      end)

    remaining = produced - MapSet.size(frozen)

    fitness = fitness_from_counts(produced, consumed, missing, remaining)

    %ReplayResult{
      produced: produced,
      consumed: consumed,
      missing: missing,
      remaining: remaining,
      fitness: fitness
    }
  end

  @doc "Computes the real Rozinat/van der Aalst token-replay fitness from real counts."
  @spec fitness_from_counts(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) ::
          float()
  def fitness_from_counts(produced, consumed, missing, remaining) do
    consumed_term = if consumed > 0, do: 1 - missing / consumed, else: 1.0
    produced_term = if produced > 0, do: 1 - remaining / produced, else: 1.0
    0.5 * consumed_term + 0.5 * produced_term
  end

  # Returns a map of leaf-label -> true for every reachable leaf in the tree
  # (silent/tau nodes contribute no place).
  defp leaf_labels(%ProcessTree{kind: :leaf, label: label}), do: %{label => true}
  defp leaf_labels(%ProcessTree{kind: :tau}), do: %{}

  defp leaf_labels(%ProcessTree{children: children}) do
    Enum.reduce(children, %{}, fn child, acc -> Map.merge(acc, leaf_labels(child)) end)
  end
end
