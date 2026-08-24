# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmDomain.BEAMOps.KanbanCard do
  @moduledoc """
  Ash Resource representing a Kanban work item card moving across lifecycle columns.
  Maps to `beamops:KanbanCard` in public ontology.
  """
  use Ash.Resource,
    domain: Ex4pmDomain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(false)
    table(:beamops_kanban_cards)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:id, :title, :description, :column, :assigned_agent, :priority, :metadata])
    end

    update :update do
      primary?(true)
      accept([:title, :description, :column, :assigned_agent, :priority, :metadata])
    end

    update :move_column do
      accept([:column])
    end
  end

  attributes do
    attribute(:id, :string, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:title, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, default: "", public?: true)
    attribute(:column, :atom, default: :backlog, public?: true)
    attribute(:assigned_agent, :string, public?: true)
    attribute(:priority, :atom, default: :medium, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)
    attribute(:ontology_class, :string, default: "beamops:KanbanCard", public?: true)
  end
end
