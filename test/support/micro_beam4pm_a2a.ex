defmodule MicroBeam4pmA2A.Agent do
  @moduledoc """
  Real `A2A.Agent` standing in for beam4pm's real, already-mounted
  `BeamPM.A2AAgent` (an `AshA2A.Agent` over `BeamPM.Ash.Domain`, per the
  companion beam4pm session's wiring: `/a2a` on port 4211, skills
  `read_ocel_events` -> `BeamPM.Ash.Resources.OcelEvent` read,
  `read_conformance_results` -> `BeamPM.Ash.Resources.ConformanceResult`
  read).

  Same "MicroBeam4pm" convention `test/support/micro_beam4pm.ex` already
  uses for `Ex4pm.Engine.Beam4pm`'s Chicago-style tests: a real, small,
  purpose-built server fixture exercising the actual wire protocol
  (real A2A JSON-RPC dispatch, real AgentCard discovery), not a mocked
  HTTP client. `handle_message/2` dispatches on the real `metadata["skill"]`
  the caller sends (the same field `A2A.Client.send_message(..., metadata:
  %{"skill" => ...})` sets) and returns real `A2A.Part.Data` parts shaped
  like a real Ash read-action JSON result (`%{"results" => [...]}`), the
  same envelope beam4pm's real skill dispatch returns.
  """
  use A2A.Agent,
    name: "beam4pm_a2a_agent",
    description: "MicroBeam4pm A2A fixture: curated OCEL event / conformance result read skills",
    skills: [
      %{
        id: "read_ocel_events",
        name: "Read OCEL Events",
        description: "Reads OCEL events (BeamPM.Ash.Resources.OcelEvent, action :read)",
        tags: ["ocel", "read"]
      },
      %{
        id: "read_conformance_results",
        name: "Read Conformance Results",
        description: "Reads conformance results (BeamPM.Ash.Resources.ConformanceResult, action :read)",
        tags: ["conformance", "read"]
      }
    ]

  @impl A2A.Agent
  def handle_message(_message, %{metadata: %{"skill" => "read_ocel_events"}}) do
    {:reply, [A2A.Part.Data.new(%{"results" => [%{"id" => "evt-1", "activity" => "commit_qualified"}]})]}
  end

  def handle_message(_message, %{metadata: %{"skill" => "read_conformance_results"}}) do
    {:reply, [A2A.Part.Data.new(%{"results" => [%{"id" => "cr-1", "fitness" => 1.0}]})]}
  end

  def handle_message(_message, _context) do
    {:error, "unsupported skill"}
  end
end

defmodule MicroBeam4pmA2A.Router do
  @moduledoc """
  Real `Plug.Router` forwarding `/a2a` to `A2A.Plug`, mirroring beam4pm's
  real `BeamPM.A2ARouter` mount shape (a thin Plug.Router forwarding
  `/a2a` to `A2A.Plug` wrapping `BeamPM.A2AAgent`), so this fixture's
  base_url/path shape matches the real deployment exactly.
  """
  use Plug.Router

  plug(:match)
  plug(:set_base_url)
  plug(:dispatch)

  forward("/a2a", to: A2A.Plug, init_opts: [agent: MicroBeam4pmA2A.Agent])

  defp set_base_url(conn, _opts) do
    A2A.Plug.put_base_url(conn, "http://#{conn.host}:#{conn.port}/a2a")
  end
end
