defmodule Ex4pm.XES do
  @moduledoc "Secure XES ingestion into the canonical event-log semantic IR."

  import SweetXml

  alias Ex4pm.{OCEL, Refusal}

  def parse(xml, opts \\ []) when is_binary(xml) do
    case_object_type = Keyword.get(opts, :case_object_type, "Case")

    try do
      document = SweetXml.parse(xml, dtd: :none)
      traces = xpath(document, ~x"//trace"el)

      if traces == [] do
        {:error, Refusal.new(:empty_xes, "XES log contains no trace elements")}
      else
        {objects, events} =
          traces
          |> Enum.with_index(1)
          |> Enum.reduce({%{}, %{}}, fn {trace, trace_index}, {objects, events} ->
            case_id =
              xpath(trace, ~x"./string[@key='concept:name']/@value"so) ||
                "trace-#{trace_index}"

            object = %{"type" => case_object_type, "xes:trace_index" => trace_index}

            trace_events =
              trace
              |> xpath(~x"./event"el)
              |> Enum.with_index(1)
              |> Enum.map(fn {event, event_index} ->
                activity = xpath(event, ~x"./string[@key='concept:name']/@value"so)
                timestamp = xpath(event, ~x"./date[@key='time:timestamp']/@value"so)

                event_id =
                  xpath(event, ~x"./string[@key='identity:id']/@value"so) ||
                    "#{case_id}:#{event_index}"

                {event_id,
                 %{
                   "activity" => activity,
                   "timestamp" => timestamp,
                   "objects" => [case_id],
                   "xes:trace_index" => trace_index,
                   "xes:event_index" => event_index
                 }}
              end)

            {Map.put(objects, case_id, object), Map.merge(events, Map.new(trace_events))}
          end)

        OCEL.normalize(%{"objects" => objects, "events" => events})
        |> case do
          {:ok, log} -> {:ok, %{log | source_format: :xes}}
          error -> error
        end
      end
    rescue
      error ->
        {:error,
         Refusal.new(:invalid_xes, "XES document could not be parsed",
           details: %{error: Exception.message(error)}
         )}
    catch
      kind, reason ->
        {:error,
         Refusal.new(:invalid_xes, "XES parser terminated abnormally",
           details: %{kind: kind, reason: inspect(reason)}
         )}
    end
  end

  def parse(other, _opts) do
    {:error, Refusal.new(:invalid_xes_subject, "XES input must be XML bytes", subject: other)}
  end
end
