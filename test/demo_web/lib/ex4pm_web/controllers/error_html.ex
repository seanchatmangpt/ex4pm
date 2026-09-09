defmodule Ex4pmWeb.ErrorHTML do
  use Ex4pmWeb, :html

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
