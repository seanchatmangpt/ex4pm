# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.IO.EventLogParser do
  @moduledoc """
  Multi-format Event Log Parser supporting CSV, XES, JSON, and newline-delimited trace files.
  """

  @type trace :: [String.t()]
  @type event_log :: [trace()]

  @doc """
  Parses an event log file from its filename and raw content string.
  """
  @spec parse(String.t(), String.t()) :: {:ok, event_log()} | {:error, String.t()}
  def parse(filename, content) do
    ext = Path.extname(filename) |> String.downcase()

    case ext do
      ".csv" -> parse_csv(content)
      ".json" -> parse_json(content)
      ".xes" -> parse_xes(content)
      _ -> parse_text_traces(content)
    end
  end

  defp parse_xes(content) do
    case Ex4pm.XES.parse(content) do
      {:ok, dataset} ->
        events_list =
          cond do
            is_map(dataset.events) -> Map.values(dataset.events)
            is_list(dataset.events) -> dataset.events
            true -> []
          end

        traces =
          events_list
          |> Enum.group_by(
            fn
              %{object_ids: [obj_id | _]} -> obj_id
              %{objects: [obj_id | _]} -> obj_id
              %{"objects" => [obj_id | _]} -> obj_id
              _ -> "default"
            end,
            fn
              %{activity: act} when is_binary(act) -> act
              %{"activity" => act} when is_binary(act) -> act
              other -> inspect(other)
            end
          )
          |> Map.values()

        {:ok, traces}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp parse_csv(content) do
    lines =
      content
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)

    case lines do
      [] ->
        {:ok, []}

      [header | data_lines] ->
        cols =
          String.split(header, [",", ";"])
          |> Enum.map(&String.trim/1)
          |> Enum.map(&String.downcase/1)

        case_idx = Enum.find_index(cols, &(&1 =~ "case" or &1 =~ "id")) || 0

        act_idx =
          Enum.find_index(cols, &(&1 =~ "activity" or &1 =~ "concept:name" or &1 =~ "task")) || 1

        traces =
          data_lines
          |> Enum.map(fn line -> String.split(line, [",", ";"]) |> Enum.map(&String.trim/1) end)
          |> Enum.filter(fn row -> length(row) > max(case_idx, act_idx) end)
          |> Enum.group_by(fn row -> Enum.at(row, case_idx) end, fn row ->
            Enum.at(row, act_idx)
          end)
          |> Map.values()

        {:ok, traces}
    end
  end

  defp parse_json(content) do
    case Jason.decode(content) do
      {:ok, list} when is_list(list) ->
        traces =
          Enum.map(list, fn
            trace when is_list(trace) ->
              Enum.map(trace, &to_string/1)

            %{"trace" => t} when is_list(t) ->
              Enum.map(t, &to_string/1)

            %{"events" => events} when is_list(events) ->
              Enum.map(events, fn
                %{"activity" => a} -> to_string(a)
                %{"type" => a} -> to_string(a)
                other -> to_string(other)
              end)

            other ->
              [to_string(other)]
          end)

        {:ok, traces}

      {:ok, %{"traces" => traces}} when is_list(traces) ->
        {:ok, traces}

      {:ok, %{"events" => events}} when is_list(events) ->
        # OCEL 2.0 list format
        traces =
          events
          |> Enum.flat_map(fn ev ->
            activity = Map.get(ev, "type") || Map.get(ev, "activity") || "unknown"
            objs = Map.get(ev, "object_ids") || Map.get(ev, "objects") || ["default"]
            Enum.map(objs, &{&1, activity})
          end)
          |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
          |> Map.values()

        {:ok, traces}

      {:ok, %{"events" => events}} when is_map(events) ->
        # OCEL 2.0 map format
        traces =
          events
          |> Map.values()
          |> Enum.flat_map(fn ev ->
            activity = Map.get(ev, "activity") || Map.get(ev, "type") || "unknown"
            objs = Map.get(ev, "objects") || Map.get(ev, "object_ids") || ["default"]
            Enum.map(objs, &{&1, activity})
          end)
          |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
          |> Map.values()

        {:ok, traces}

      _ ->
        {:error, "invalid JSON event log structure"}
    end
  end

  defp parse_text_traces(content) do
    traces =
      content
      |> String.split("\n", trim: true)
      |> Enum.map(fn line ->
        String.split(line, [",", "->", " ", "\t"], trim: true)
        |> Enum.map(&String.trim/1)
      end)
      |> Enum.reject(&(&1 == []))

    {:ok, traces}
  end
end
