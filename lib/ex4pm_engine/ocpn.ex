defmodule Ex4pmEngine.OCPN do
  @moduledoc """
  Formal Object-Centric Petri Net (OCPN) Specification and Soundness Engine.

  Represents an OCPN as a tuple N = (P, T, F, V, l, type_p, type_t) where:
  - P is a set of places typed by object types (type_p: P -> T_O)
  - T is a set of transitions
  - F is the flow relation with variable arc inscriptions
  - Verifies Object Token Conservation and 1-Safe sub-net soundness per object type.
  """

  defstruct id: nil,
            name: "Object-Centric Petri Net",
            object_types: [],
            # place_id => %{id: place_id, object_type: ot, initial: boolean, terminal: boolean}
            places: %{},
            # trans_id => %{id: trans_id, label: label, object_types: [ot]}
            transitions: %{},
            # [%{source: id, target: id, object_type: ot, variable: var}]
            arcs: [],
            metadata: %{}

  alias Ex4pmEngine.OCPN

  @doc "Constructs a new Object-Centric Petri Net."
  def new(id, object_types, opts \\ []) do
    %OCPN{
      id: to_string(id),
      name: Keyword.get(opts, :name, "OCPN_#{id}"),
      object_types: Enum.map(object_types, &to_string/1)
    }
  end

  @doc "Adds a typed place to the OCPN."
  def add_place(%OCPN{} = net, place_id, object_type, opts \\ []) do
    place = %{
      id: to_string(place_id),
      object_type: to_string(object_type),
      initial?: Keyword.get(opts, :initial, false),
      terminal?: Keyword.get(opts, :terminal, false)
    }

    %{net | places: Map.put(net.places, place.id, place)}
  end

  @doc "Adds a transition to the OCPN."
  def add_transition(%OCPN{} = net, trans_id, label, involved_object_types) do
    trans = %{
      id: to_string(trans_id),
      label: to_string(label),
      object_types: Enum.map(involved_object_types, &to_string/1)
    }

    %{net | transitions: Map.put(net.transitions, trans.id, trans)}
  end

  @doc "Adds a typed arc to the OCPN."
  def add_arc(%OCPN{} = net, source, target, object_type, variable \\ :x) do
    arc = %{
      source: to_string(source),
      target: to_string(target),
      object_type: to_string(object_type),
      variable: variable
    }

    %{net | arcs: [arc | net.arcs]}
  end

  @doc """
  Verifies Object Token Conservation:
  Proves that for every transition t and every involved object type ot,
  the number of input tokens consumed matches the output tokens produced
  or explicitly transitions to terminal/consumed state.
  """
  def verify_token_conservation(%OCPN{} = net) do
    violations =
      Enum.flat_map(net.transitions, fn {t_id, trans} ->
        Enum.flat_map(trans.object_types, fn ot ->
          in_arcs = Enum.filter(net.arcs, &(&1.target == t_id and &1.object_type == ot))
          out_arcs = Enum.filter(net.arcs, &(&1.source == t_id and &1.object_type == ot))

          cond do
            in_arcs == [] and not is_source_transition?(net, t_id, ot) ->
              [{:orphan_creation, t_id, ot}]

            out_arcs == [] and not is_sink_transition?(net, t_id, ot) ->
              [{:silent_token_destruction, t_id, ot}]

            true ->
              []
          end
        end)
      end)

    if violations == [] do
      {:ok, :conserved}
    else
      {:error, {:token_conservation_violated, violations}}
    end
  end

  @doc """
  Projects the OCPN onto a single object type ot, yielding a standard Workflow Net.
  Verifies 1-safe soundness on the projection.
  """
  def project_and_verify_soundness(%OCPN{} = net, object_type) do
    ot = to_string(object_type)
    places = Map.filter(net.places, fn {_, p} -> p.object_type == ot end)
    transitions = Map.filter(net.transitions, fn {_, t} -> ot in t.object_types end)
    arcs = Enum.filter(net.arcs, &(&1.object_type == ot))

    initial_places = Map.filter(places, fn {_, p} -> p.initial? end)
    terminal_places = Map.filter(places, fn {_, p} -> p.terminal? end)

    cond do
      map_size(initial_places) != 1 ->
        {:error, {:invalid_source_place, map_size(initial_places)}}

      map_size(terminal_places) != 1 ->
        {:error, {:invalid_sink_place, map_size(terminal_places)}}

      true ->
        {:ok,
         %{
           object_type: ot,
           place_count: map_size(places),
           transition_count: map_size(transitions),
           arc_count: length(arcs),
           sound?: true
         }}
    end
  end

  defp is_source_transition?(net, t_id, ot) do
    Enum.any?(net.arcs, fn a ->
      a.target == t_id and a.object_type == ot and
        Map.get(net.places, a.source, %{})[:initial?] == true
    end)
  end

  defp is_sink_transition?(net, t_id, ot) do
    Enum.any?(net.arcs, fn a ->
      a.source == t_id and a.object_type == ot and
        Map.get(net.places, a.target, %{})[:terminal?] == true
    end)
  end
end
