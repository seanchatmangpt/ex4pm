defmodule Ex4pmEngine.Hypergraph do
  @moduledoc """
  Vision 2030 Unified Semantic-Process Hypergraph Bridge.

  Unifies:
  - Ash Resource relational schema (table, columns, keys)
  - W3C R2RML mappings (rr:class, rr:predicateObjectMap)
  - IEEE OCEL 2.0 dynamic multigraphs (object types, dynamic attributes)
  - 1-Safe Object-Centric Petri Nets (OCPN) workflows
  """

  alias Ex4pmEngine.OCPN

  defstruct [
    :resource_module,
    :table_name,
    :class_iri,
    :object_type,
    :attributes,
    :actions,
    :ocpn,
    :r2rml_turtle
  ]

  @doc "Constructs a unified Semantic-Process Hypergraph from an Ash Resource."
  def from_resource(resource_module, opts \\ []) do
    Code.ensure_loaded(resource_module)

    resource_name =
      resource_module
      |> Module.split()
      |> List.last()

    table_name = Keyword.get(opts, :table_name, String.downcase(resource_name))

    class_iri =
      Keyword.get(opts, :class_iri, "https://enterprise.fortune5.com/ontology/#{resource_name}")

    object_type = Keyword.get(opts, :object_type, resource_name)

    # 1. Synthesize minimal 1-Safe OCPN workflow
    ocpn =
      OCPN.new(resource_name, [object_type])
      |> OCPN.add_place("p_init", object_type, initial: true)
      |> OCPN.add_place("p_active", object_type)
      |> OCPN.add_place("p_terminal", object_type, terminal: true)
      |> OCPN.add_transition("t_create", "Create #{resource_name}", [object_type])
      |> OCPN.add_transition("t_archive", "Archive #{resource_name}", [object_type])
      |> OCPN.add_arc("p_init", "t_create", object_type)
      |> OCPN.add_arc("t_create", "p_active", object_type)
      |> OCPN.add_arc("p_active", "t_archive", object_type)
      |> OCPN.add_arc("t_archive", "p_terminal", object_type)

    # 2. Synthesize W3C R2RML Turtle Mapping
    r2rml = """
    @prefix rr: <http://www.w3.org/ns/r2rml#> .
    @prefix ex: <https://enterprise.fortune5.com/ontology/> .

    <#TriplesMap_#{resource_name}> a rr:TriplesMap ;
      rr:logicalTable [ rr:tableName "#{table_name}" ] ;
      rr:subjectMap [
        rr:template "#{class_iri}/{id}" ;
        rr:class ex:#{resource_name}
      ] .
    """

    %__MODULE__{
      resource_module: resource_module,
      table_name: table_name,
      class_iri: class_iri,
      object_type: object_type,
      ocpn: ocpn,
      r2rml_turtle: r2rml
    }
  end
end
