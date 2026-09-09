defmodule Ex4pmEngine.Cognition.Interview do
  @moduledoc """
  InterviewAssist active inquiry protocol.
  Manages structured qualification question trees, response evaluations,
  and ambiguity reduction scoring for human-in-the-loop and agent-to-agent alignment.
  """

  defmodule Question do
    @moduledoc "A structured qualification or clarification question."
    @enforce_keys [:id, :prompt, :options]
    defstruct [:id, :prompt, :options, :category, metadata: %{}]
  end

  @doc "Evaluates an answer against accepted options and calculates remaining ambiguity score."
  def evaluate_response(question, chosen_option) do
    chosen_str = to_string(chosen_option)
    valid_option? = chosen_str in Enum.map(question.options, &to_string/1)

    if valid_option? do
      {:ok,
       %{
         accepted?: true,
         chosen_option: chosen_str,
         ambiguity_reduction: 1.0 / length(question.options),
         timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
       }}
    else
      {:error,
       %{
         accepted?: false,
         reason: :invalid_choice,
         valid_options: question.options
       }}
    end
  end
end
