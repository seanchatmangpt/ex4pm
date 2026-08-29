defmodule Ex4pm.Runtime.PowlExecutor do
  @moduledoc """
  A real `GenStateMachine` implementing a Petri-net-style token game for a
  POWL process model.

  The machine's state is a marking: a map of `place -> non_neg_integer`
  token counts. The single state-machine state is `:marking` (this executor
  is deliberately single-mode — the "state" that matters is the data, not the
  state-function name), and the machine data carries both the current marking
  and the transition graph it was started with.

  A transition is identified by any term (usually an atom or string) and is
  described by its input places (consumed on fire) and output places
  (produced on fire). Firing a transition whose input places do not all hold
  at least one token is refused: the marking is left unchanged and the caller
  receives `{:error, :insufficient_tokens}`.

  This module is intentionally self-contained: it has no dependency on BRCE
  or receipts. Wiring a receipted `:fire` call is a later capability's job.
  """

  use GenStateMachine, callback_mode: :state_functions

  @type place :: term()
  @type transition_id :: term()
  @type marking :: %{optional(place) => non_neg_integer()}
  @type transition :: %{inputs: [place], outputs: [place]}
  @type transitions :: %{optional(transition_id) => transition}

  defmodule Data do
    @moduledoc false
    @enforce_keys [:marking, :transitions]
    defstruct [:marking, :transitions]
  end

  @doc """
  Start the executor.

  `initial_marking` is a map of place => token count. `transitions` is a map
  of transition_id => %{inputs: [place], outputs: [place]}.
  """
  @spec start_link(marking, transitions, GenServer.options()) :: GenServer.on_start()
  def start_link(initial_marking, transitions, opts \\ [])
      when is_map(initial_marking) and is_map(transitions) do
    data = %Data{marking: initial_marking, transitions: transitions}
    GenStateMachine.start_link(__MODULE__, data, opts)
  end

  @doc """
  Attempt to fire `transition_id`. Returns `{:ok, marking}` with the new
  marking on success, or `{:error, :insufficient_tokens}` /
  `{:error, :unknown_transition}` on refusal, in which case the marking is
  left unchanged.
  """
  @spec fire(GenServer.server(), transition_id) ::
          {:ok, marking} | {:error, :insufficient_tokens | :unknown_transition}
  def fire(server, transition_id) do
    GenStateMachine.call(server, {:fire, transition_id})
  end

  @doc "Return the current marking."
  @spec marking(GenServer.server()) :: marking
  def marking(server), do: GenStateMachine.call(server, :marking)

  # -- gen_statem callbacks -------------------------------------------------

  @impl GenStateMachine
  def init(%Data{} = data), do: {:ok, :marking, data}

  # state name is :marking throughout — this is a single-state token-game
  # machine, all the interesting transitions live in the *data*.
  def marking(:enter, _old_state, _data), do: :keep_state_and_data

  def marking({:call, from}, :marking, %Data{marking: marking} = data) do
    {:keep_state, data, [{:reply, from, marking}]}
  end

  def marking({:call, from}, {:fire, transition_id}, %Data{} = data) do
    case Map.fetch(data.transitions, transition_id) do
      :error ->
        {:keep_state, data, [{:reply, from, {:error, :unknown_transition}}]}

      {:ok, %{inputs: inputs, outputs: outputs}} ->
        if enabled?(data.marking, inputs) do
          new_marking =
            data.marking
            |> consume(inputs)
            |> produce(outputs)

          new_data = %Data{data | marking: new_marking}
          {:keep_state, new_data, [{:reply, from, {:ok, new_marking}}]}
        else
          {:keep_state, data, [{:reply, from, {:error, :insufficient_tokens}}]}
        end
    end
  end

  defp enabled?(marking, inputs) do
    Enum.all?(inputs, fn place -> Map.get(marking, place, 0) > 0 end)
  end

  defp consume(marking, inputs) do
    Enum.reduce(inputs, marking, fn place, acc ->
      Map.update(acc, place, 0, &max(&1 - 1, 0))
    end)
  end

  defp produce(marking, outputs) do
    Enum.reduce(outputs, marking, fn place, acc ->
      Map.update(acc, place, 1, &(&1 + 1))
    end)
  end
end
