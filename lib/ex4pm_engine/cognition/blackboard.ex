defmodule Ex4pmEngine.Cognition.Blackboard do
  @moduledoc """
  Hearsay-II hierarchical Blackboard architecture.
  Supports multi-level hypothesis posts, knowledge source (KS) triggers, and opportunistic reasoning.
  """

  @enforce_keys [:levels]
  defstruct [:levels, hypotheses: %{}, history: [], metadata: %{}]

  defmodule Hypothesis do
    @moduledoc "A hypothesis posted to a specific level of the blackboard."
    @enforce_keys [:id, :level, :content]
    defstruct [:id, :level, :content, confidence: 1.0, source: :user, support: [], metadata: %{}]
  end

  @doc "Creates a new blackboard with specified abstraction levels."
  def new(
        levels \\ ["signal", "segment", "phonetic", "lexical", "syntactic", "semantic", "process"]
      ) do
    %__MODULE__{
      levels: levels,
      hypotheses: Map.new(levels, &{&1, []}),
      history: []
    }
  end

  @doc "Posts a new hypothesis to a blackboard level."
  def post_hypothesis(%__MODULE__{} = bb, level, content, opts \\ []) do
    id = Keyword.get(opts, :id, "hyp_#{System.unique_integer([:positive])}")
    confidence = Keyword.get(opts, :confidence, 1.0)
    source = Keyword.get(opts, :source, :knowledge_source)
    support = Keyword.get(opts, :support, [])

    hyp = %Hypothesis{
      id: to_string(id),
      level: to_string(level),
      content: content,
      confidence: confidence,
      source: source,
      support: support
    }

    current_level_hyps = Map.get(bb.hypotheses, to_string(level), [])
    new_hyps = Map.put(bb.hypotheses, to_string(level), [hyp | current_level_hyps])

    %{bb | hypotheses: new_hyps, history: [{:post, hyp} | bb.history]}
  end

  @doc "Retrieves hypotheses at a given abstraction level, optionally filtered by minimum confidence."
  def get_level(%__MODULE__{} = bb, level, min_confidence \\ 0.0) do
    Map.get(bb.hypotheses, to_string(level), [])
    |> Enum.filter(&(&1.confidence >= min_confidence))
  end
end
