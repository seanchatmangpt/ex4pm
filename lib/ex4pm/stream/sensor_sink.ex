defmodule Ex4pm.Stream.SensorSink do
  @moduledoc """
  Real threshold-crossing abstraction from raw numeric sensor samples into
  canonical `%Ex4pm.Event{}` observations.

  A raw sensor reading is `{value, timestamp, sensor_id}`. This module applies
  a real (if simple) abstraction rule: an `%Ex4pm.Event{}` is emitted only on a
  crossing edge of a configured threshold (value goes from at-or-below the
  threshold to strictly above it, or vice versa for a falling-edge rule) — not
  on every sample. This is the discretization step that turns a continuous
  signal into discrete process-mining events, matching the canonical event IR
  from `Ex4pm.Event` (`apps/ex4pm_core/lib/ex4pm/ocel.ex`) so downstream
  discovery/conformance can consume sensor-originated events identically to
  any other event source.

  Usable directly as a Broadway `context.sink`-style callback (`handle_message/2`)
  matching `Ex4pm.Stream.Pipeline`'s sink contract, or driven synchronously via
  `sample/2`/`sample_all/2` for a plain message-handling loop.
  """

  alias Ex4pm.Event

  @type reading :: {number(), DateTime.t() | non_neg_integer(), String.t()}

  @type t :: %__MODULE__{
          threshold: number(),
          rising_activity: String.t(),
          falling_activity: String.t(),
          last_state: %{optional(String.t()) => :above | :at_or_below},
          emitted: non_neg_integer()
        }

  defstruct threshold: 0.0,
            rising_activity: "threshold_crossed_above",
            falling_activity: "threshold_crossed_below",
            last_state: %{},
            emitted: 0

  @doc "New sensor abstraction state. Options: `:threshold`, `:rising_activity`, `:falling_activity`."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      threshold: Keyword.get(opts, :threshold, 0.0),
      rising_activity: Keyword.get(opts, :rising_activity, "threshold_crossed_above"),
      falling_activity: Keyword.get(opts, :falling_activity, "threshold_crossed_below")
    }
  end

  @doc """
  Fold one raw sample into the abstraction state. Returns `{new_state, event_or_nil}`
  — `nil` when the sample did not cross the threshold (the common case: most raw
  samples are abstraction-irrelevant noise around a steady state).
  """
  @spec sample(t(), reading()) :: {t(), Event.t() | nil}
  def sample(%__MODULE__{} = state, {value, timestamp, sensor_id}) do
    band = if value > state.threshold, do: :above, else: :at_or_below

    case Map.fetch(state.last_state, sensor_id) do
      {:ok, ^band} ->
        {state, nil}

      {:ok, :at_or_below} when band == :above ->
        emit(state, sensor_id, timestamp, value, state.rising_activity)

      {:ok, :above} when band == :at_or_below ->
        emit(state, sensor_id, timestamp, value, state.falling_activity)

      :error ->
        {%{state | last_state: Map.put(state.last_state, sensor_id, band)}, nil}
    end
  end

  @doc "Fold a real sequence of raw samples, returning the final state and the ordered list of abstracted events."
  @spec sample_all(t(), [reading()]) :: {t(), [Event.t()]}
  def sample_all(%__MODULE__{} = state, readings) when is_list(readings) do
    {final_state, events_rev} =
      Enum.reduce(readings, {state, []}, fn reading, {acc_state, acc_events} ->
        case sample(acc_state, reading) do
          {new_state, nil} -> {new_state, acc_events}
          {new_state, event} -> {new_state, [event | acc_events]}
        end
      end)

    {final_state, Enum.reverse(events_rev)}
  end

  @doc """
  Broadway sink-compatible message handler: unwraps a `%Broadway.Message{data: reading}`,
  abstracts it against the state held in `context`, and forwards any emitted event to
  `context.forward.(event)`. Matches `Ex4pm.Stream.Pipeline`'s "sinks receive
  observations only" contract — no DO authority is exercised here.
  """
  @spec handle_message(Broadway.Message.t(), %{
          sink_state: pid() | t(),
          forward: (Event.t() -> any())
        }) ::
          Broadway.Message.t()
  def handle_message(%Broadway.Message{data: reading} = message, %{
        sink_state: state,
        forward: forward
      })
      when is_function(forward, 1) do
    case sample(state, reading) do
      {_new_state, nil} -> :ok
      {_new_state, event} -> forward.(event)
    end

    message
  end

  defp emit(state, sensor_id, timestamp, value, activity) do
    event = %Event{
      id: "sensor:#{sensor_id}:#{state.emitted}",
      activity: activity,
      timestamp: timestamp,
      object_ids: [sensor_id],
      relationships: [],
      attributes: %{value: value}
    }

    new_state = %{
      state
      | last_state: Map.put(state.last_state, sensor_id, band_of(state, value)),
        emitted: state.emitted + 1
    }

    {new_state, event}
  end

  defp band_of(state, value), do: if(value > state.threshold, do: :above, else: :at_or_below)
end
