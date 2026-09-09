defmodule Ex4pmWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint Ex4pmWeb.Endpoint

      use Ex4pmWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
