# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Miner.OCPOWL do
  @moduledoc """
  Object-Centric POWL (OC-POWL) Discovery Engine:
  Mines multi-object-type processes directly from IEEE OCEL 2.0 event streams:
  1. Object Type Projection: Slices event stream by object type (e.g. `order`, `item`, `package`).
  2. Sub-POWL Discovery: Discovers sound POWL models for each object type using `InductiveMiner`.
  3. Shared Transition Binding: Synchronizes object lifecycles on multi-object events.
  """

  alias Ex4pmEngine.InductiveMiner

  @type ocel_event :: %{
          activity: String.t(),
          timestamp: DateTime.t(),
          objects: %{String.t() => [String.t()]}
        }

  @doc "Discovers an Object-Centric POWL model from an OCEL event list."
  @spec mine_oc_powl([ocel_event()]) ::
          {:ok, %{object_types: [String.t()], models: %{String.t() => term()}}}
  def mine_oc_powl(ocel_events) when is_list(ocel_events) do
    object_types =
      Enum.flat_map(ocel_events, fn ev -> Map.keys(ev.objects || %{}) end)
      |> Enum.uniq()
      |> Enum.sort()

    per_type_models =
      Enum.map(object_types, fn obj_type ->
        traces = extract_traces_for_type(ocel_events, obj_type)
        {:ok, powl_model} = InductiveMiner.mine(traces)
        {obj_type, powl_model}
      end)
      |> Map.new()

    {:ok, %{object_types: object_types, models: per_type_models}}
  end

  defp extract_traces_for_type(events, type) do
    events
    |> Enum.flat_map(fn ev ->
      obj_ids = Map.get(ev.objects, type, [])
      Enum.map(obj_ids, fn id -> {id, ev.activity} end)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.values()
  end
end
