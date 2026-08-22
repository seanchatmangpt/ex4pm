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
      _ -> parse_text_traces(content)
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
        cols = String.split(header, [",", ";"]) |> Enum.map(&String.trim/1) |> Enum.map(&String.downcase/1)
        case_idx = Enum.find_index(cols, &(&1 =~ "case" or &1 =~ "id")) || 0
        act_idx = Enum.find_index(cols, &(&1 =~ "activity" or &1 =~ "concept:name" or &1 =~ "task")) || 1

        traces =
          data_lines
          |> Enum.map(fn line -> String.split(line, [",", ";"]) |> Enum.map(&String.trim/1) end)
          |> Enum.filter(fn row -> length(row) > max(case_idx, act_idx) end)
          |> Enum.group_by(fn row -> Enum.at(row, case_idx) end, fn row -> Enum.at(row, act_idx) end)
          |> Map.values()

        {:ok, traces}
    end
  end

  defp parse_json(content) do
    case Jason.decode(content) do
      {:ok, list} when is_list(list) ->
        traces =
          Enum.map(list, fn
            trace when is_list(trace) -> Enum.map(trace, &to_string/1)
            %{"trace" => t} when is_list(t) -> Enum.map(t, &to_string/1)
            %{"events" => events} when is_list(events) ->
              Enum.map(events, fn
                %{"activity" => a} -> to_string(a)
                other -> to_string(other)
              end)
            other -> [to_string(other)]
          end)
        {:ok, traces}

      {:ok, %{"traces" => traces}} when is_list(traces) ->
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
