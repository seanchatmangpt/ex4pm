defmodule Ex4pm.Stream.Producer do
  @moduledoc "Finite Broadway producer for admitted observation enumerables."

  use GenStage
  @behaviour Broadway.Acknowledger

  def start_link(opts), do: GenStage.start_link(__MODULE__, opts)

  @impl true
  def init(opts) do
    events = opts |> Keyword.fetch!(:events) |> Enum.to_list()
    {:producer, %{events: events}}
  end

  @impl true
  def handle_demand(demand, %{events: events} = state) when demand > 0 do
    {to_emit, remaining} = Enum.split(events, demand)

    messages =
      Enum.map(to_emit, fn event ->
        %Broadway.Message{
          data: event,
          acknowledger: {__MODULE__, make_ref(), nil}
        }
      end)

    {:noreply, messages, %{state | events: remaining}}
  end

  @impl Broadway.Acknowledger
  def ack(_ack_ref, _successful, _failed), do: :ok
end

defmodule Ex4pm.Stream.Pipeline do
  @moduledoc "Broadway process-observation pipeline. Sinks receive observations, never ambient DO authority."

  use Broadway

  alias Broadway.Message
  alias Ex4pm.{Event, OCEL}

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    sink = Keyword.fetch!(opts, :sink)
    events = Keyword.fetch!(opts, :events)
    objects = Keyword.get(opts, :objects, %{})

    Broadway.start_link(__MODULE__,
      name: name,
      context: %{sink: sink, objects: objects},
      producer: [
        module: {Ex4pm.Stream.Producer, [events: events]},
        concurrency: Keyword.get(opts, :producer_concurrency, 1)
      ],
      processors: [
        default: [
          concurrency: Keyword.get(opts, :processor_concurrency, System.schedulers_online())
        ]
      ]
    )
  end

  @impl true
  def handle_message(_processor, %Message{data: %Event{} = event} = message, %{sink: sink}) do
    sink.(event)
    message
  end

  def handle_message(_processor, %Message{data: raw} = message, %{sink: sink, objects: objects}) do
    case OCEL.normalize(%{events: [raw], objects: objects}) do
      {:ok, %{events: [event]}} ->
        sink.(event)
        Message.update_data(message, fn _ -> event end)

      {:error, refusal} ->
        Message.failed(message, refusal)
    end
  end
end
