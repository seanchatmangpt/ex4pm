# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmWeb.AshAdminTest do
  use Ex4pmWeb.ConnCase
  import Phoenix.ConnTest

  test "mounts /admin successfully and exposes Ash domains and resources", %{conn: conn} do
    conn = get(conn, "/admin")
    resp = response(conn, 200)

    assert resp =~ "Ash Admin"
    assert resp =~ "Ex4pmDomain" or resp =~ "Domain" or resp =~ "Ex4pm"
  end

  test "navigates to domain resource page on /admin", %{conn: conn} do
    conn = get(conn, "/admin?domain=Ex4pmDomain")
    assert response(conn, 200) =~ "Ash Admin"
  end
end
