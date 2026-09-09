defmodule Ex4pmWeb.CoreComponents do
  @moduledoc """
  Core UI components for Process Intelligence Control Plane.
  """
  use Phoenix.Component

  attr(:id, :string, default: nil)
  slot(:inner_block, required: true)

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end
end
