defmodule Engine.Beam4pmTest do
  use ExUnit.Case, async: false

  # Real, no-mock test: starts a REAL local Bandit server hosting a real
  # Plug.Router that mimics one AshJsonApi-shaped response, and points
  # Ex4pm.Engine.Beam4pm's real Req-based HTTP call at it. beam4pm itself
  # does not expose this live yet (see priv/ontology/ex4pm.ttl's ex4pmb:
  # prefix comment) -- this proves the generated client's own HTTP/parsing
  # mechanics are real and correct, independent of that separate,
  # disclosed prerequisite.

  alias Ex4pm.Engine.Beam4pm

  defmodule FakeBeam4pmRouter do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    get "/ocel_event" do
      conn = Plug.Conn.fetch_query_params(conn)

      case conn.query_params["action"] do
        "read" ->
          body =
            Jason.encode!(%{
              "data" => [%{"id" => "e1", "type" => "ocel_event", "attributes" => %{"activity" => "commit_qualified"}}],
              "meta" => %{"source_sha" => "abc123real", "receipt_verified" => true}
            })

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, body)

        _ ->
          Plug.Conn.send_resp(conn, 400, Jason.encode!(%{"error" => "unknown action"}))
      end
    end

    get "/conformance_result" do
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "boom"}))
    end

    match _ do
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "not_found"}))
    end
  end

  setup do
    port = Enum.random(20_000..29_999)
    {:ok, pid} = Bandit.start_link(plug: FakeBeam4pmRouter, port: port, ip: {127, 0, 0, 1})
    on_exit(fn -> Process.exit(pid, :normal) end)
    {:ok, base_url: "http://127.0.0.1:#{port}"}
  end

  test "id/0 and the ontology-admitted route table" do
    assert Beam4pm.id() == :beam4pm
    assert Beam4pm.supports?(:beam4pm_ocel_events, [])
    assert Beam4pm.supports?(:beam4pm_conformance_results, [])
    refute Beam4pm.supports?(:not_an_admitted_operation, [])
  end

  test "available?/1 requires a configured base_url" do
    refute Beam4pm.available?([])
    assert Beam4pm.available?(beam4pm_base_url: "http://127.0.0.1:1")
  end

  test "a real successful request against a real local JSON:API-shaped server reaches :alive standing", %{
    base_url: base_url
  } do
    {:ok, result} = Beam4pm.execute(:beam4pm_ocel_events, %{id: "e1"}, beam4pm_base_url: base_url)

    assert result.engine == :beam4pm
    assert result.standing == :alive
    assert [%{"id" => "e1"}] = result.value
    assert result.evidence.beam4pm_identity == %{source_sha: "abc123real", receipt_verified: true}
  end

  test "an unadmitted operation is refused, never silently attempted", %{base_url: base_url} do
    assert {:error, refusal} = Beam4pm.execute(:not_an_admitted_operation, %{}, beam4pm_base_url: base_url)
    assert refusal.code == :beam4pm_unsupported_operation
  end

  test "no configured base_url is refused as unavailable, not a crash" do
    assert {:error, refusal} = Beam4pm.execute(:beam4pm_ocel_events, %{id: "e1"}, [])
    assert refusal.code == :beam4pm_unavailable
  end

  test "a real non-2xx response from a real server is refused with the real status", %{base_url: base_url} do
    assert {:error, refusal} =
             Beam4pm.execute(:beam4pm_conformance_results, %{id: "c1"}, beam4pm_base_url: base_url)

    assert refusal.code == :beam4pm_http_error
    assert refusal.details.status == 500
  end

  test "a real connection failure (server not listening) is refused as unavailable" do
    assert {:error, refusal} =
             Beam4pm.execute(:beam4pm_ocel_events, %{id: "e1"}, beam4pm_base_url: "http://127.0.0.1:1")

    assert refusal.code == :beam4pm_unavailable
  end
end
