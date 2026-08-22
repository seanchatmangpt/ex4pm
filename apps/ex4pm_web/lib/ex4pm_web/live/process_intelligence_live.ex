defmodule Ex4pmWeb.ProcessIntelligenceLive do
  use Ex4pmWeb, :live_view

  alias Ex4pm.Engine.OnlineMiner

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Ex4pmWeb.PubSub, "process_intelligence:live")
    end

    socket =
      socket
      |> assign_metrics()
      |> assign_defaults()

    {:ok, socket}
  end

  @impl true
  def handle_info({:miner_update, _type, _data}, socket) do
    {:noreply, assign_metrics(socket)}
  end

  def handle_info({:ocel_ingested, envelope}, socket) do
    new_event_summaries =
      envelope.events
      |> Enum.map(fn ev ->
        %{
          id: Map.get(ev, "id") || Map.get(ev, :id, "ev"),
          activity: Map.get(ev, "activity") || Map.get(ev, :activity, "unknown"),
          timestamp:
            Map.get(ev, "timestamp") ||
              Map.get(ev, :timestamp, DateTime.utc_now() |> DateTime.to_iso8601()),
          agent_id:
            Map.get(envelope.producer, "agent_id") ||
              Map.get(envelope.producer, :agent_id, "unknown"),
          standing: :alive
        }
      end)

    updated_feed = Enum.take(new_event_summaries ++ socket.assigns.live_events, 30)

    {:noreply,
     socket
     |> assign(live_events: updated_feed)
     |> assign_metrics()}
  end

  def handle_info({:refusal_emitted, refusal}, socket) do
    refusal_entry = %{
      code: refusal.code,
      message: refusal.message,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      details: refusal.details
    }

    updated_refusals = Enum.take([refusal_entry | socket.assigns.recent_refusals], 15)

    {:noreply,
     socket
     |> assign(recent_refusals: updated_refusals)
     |> assign_metrics()}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, assign_metrics(socket)}
  end

  def handle_event("reset_stats", _params, socket) do
    if Process.whereis(OnlineMiner) do
      OnlineMiner.reset(OnlineMiner)
    end

    {:noreply,
     socket
     |> assign(live_events: [], recent_refusals: [])
     |> assign_metrics()}
  end

  defp assign_defaults(socket) do
    assign(socket,
      live_events: [],
      recent_refusals: []
    )
  end

  defp assign_metrics(socket) do
    miner = Process.whereis(OnlineMiner)

    if miner do
      summary = OnlineMiner.get_summary(miner)
      fleet = OnlineMiner.get_fleet_status(miner)
      dfg = OnlineMiner.get_dfg(miner)
      variants = OnlineMiner.get_variants(miner)
      conformance = OnlineMiner.get_conformance(miner)

      assign(socket,
        summary: summary,
        fleet: fleet,
        dfg: dfg,
        variants: variants,
        conformance: conformance
      )
    else
      assign(socket,
        summary: %{
          total_events: 0,
          active_agents: 0,
          total_agents: 0,
          total_variants: 0,
          dfg_edge_count: 0,
          conformance_fitness: 1.0,
          refusal_count: 0
        },
        fleet: [],
        dfg: %{type: :dfg, activities: %{}, edges: %{}, starts: %{}, ends: %{}, trace_count: 0},
        variants: [],
        conformance: %{
          fitness: 1.0,
          observed_transitions: 0,
          non_conformant_transitions: 0,
          deviations: %{},
          recent_refusals: []
        }
      )
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Top Bar / Title -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-extrabold tracking-tight text-white flex items-center gap-3">
            <span>Process Intelligence Control Plane</span>
            <span class="text-xs bg-emerald-950 text-emerald-400 border border-emerald-800 px-2 py-0.5 rounded font-mono font-normal">
              LIVE OCEL 2.0
            </span>
          </h1>
          <p class="text-gray-400 text-sm mt-1">
            Real-time Van der Aalst object-centric process mining & Armstrong fault-isolated actor control plane.
          </p>
        </div>
        <div class="flex items-center space-x-3">
          <button phx-click="refresh" class="px-3 py-1.5 rounded bg-gray-800 hover:bg-gray-700 text-gray-200 text-xs font-mono transition">
            ↻ Refresh
          </button>
          <button phx-click="reset_stats" class="px-3 py-1.5 rounded bg-red-950 hover:bg-red-900 border border-red-800 text-red-300 text-xs font-mono transition">
            Reset Metrics
          </button>
        </div>
      </div>

      <!-- KPI Fleet Metrics Grid -->
      <div class="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div class="bg-[#121829] border border-gray-800 rounded-xl p-4">
          <div class="text-xs font-mono uppercase text-gray-400">Total Events</div>
          <div class="text-2xl font-bold font-mono text-emerald-400 mt-1">
            <%= @summary.total_events %>
          </div>
          <div class="text-[11px] text-gray-500 mt-1">Streamed observations</div>
        </div>

        <div class="bg-[#121829] border border-gray-800 rounded-xl p-4">
          <div class="text-xs font-mono uppercase text-gray-400">Active Agents</div>
          <div class="text-2xl font-bold font-mono text-cyan-400 mt-1">
            <%= @summary.active_agents %> / <%= @summary.total_agents %>
          </div>
          <div class="text-[11px] text-gray-500 mt-1">Fleet state machines</div>
        </div>

        <div class="bg-[#121829] border border-gray-800 rounded-xl p-4">
          <div class="text-xs font-mono uppercase text-gray-400">Conformance</div>
          <div class="text-2xl font-bold font-mono text-indigo-400 mt-1">
            <%= Float.round(@summary.conformance_fitness * 100, 1) %>%
          </div>
          <div class="text-[11px] text-gray-500 mt-1">BEAM process law fitness</div>
        </div>

        <div class="bg-[#121829] border border-gray-800 rounded-xl p-4">
          <div class="text-xs font-mono uppercase text-gray-400">Variants</div>
          <div class="text-2xl font-bold font-mono text-amber-400 mt-1">
            <%= @summary.total_variants %>
          </div>
          <div class="text-[11px] text-gray-500 mt-1">Discovered paths</div>
        </div>

        <div class="bg-[#121829] border border-gray-800 rounded-xl p-4">
          <div class="text-xs font-mono uppercase text-gray-400">Refusals</div>
          <div class="text-2xl font-bold font-mono text-rose-400 mt-1">
            <%= @summary.refusal_count %>
          </div>
          <div class="text-[11px] text-gray-500 mt-1">Typed BRCE denials</div>
        </div>
      </div>

      <!-- Main Fleet & Mining Layout -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- Left 2 Cols: Fleet Status & Discovered DFG -->
        <div class="lg:col-span-2 space-y-8">
          <!-- Active Agent Fleet -->
          <div class="bg-[#121829] border border-gray-800 rounded-xl overflow-hidden">
            <div class="px-5 py-3.5 border-b border-gray-800 flex items-center justify-between bg-[#151c30]">
              <h2 class="text-sm font-bold uppercase tracking-wider text-gray-200 flex items-center gap-2 font-mono">
                <span>⚡ Active Agent Fleet</span>
                <span class="text-xs text-gray-400 font-normal">(<%= length(@fleet) %> total)</span>
              </h2>
            </div>

            <div class="overflow-x-auto">
              <table class="w-full text-left text-xs font-mono">
                <thead class="bg-[#0f1422] text-gray-400 border-b border-gray-800">
                  <tr>
                    <th class="px-4 py-3">Agent</th>
                    <th class="px-4 py-3">Repository</th>
                    <th class="px-4 py-3">State</th>
                    <th class="px-4 py-3">Last Activity</th>
                    <th class="px-4 py-3">Events</th>
                    <th class="px-4 py-3">Standing</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-800/60 text-gray-300">
                  <%= if @fleet == [] do %>
                    <tr>
                      <td colspan="6" class="px-4 py-6 text-center text-gray-500 italic">
                        No active agents observed yet. Send events to POST /api/v1/ocel/events.
                      </td>
                    </tr>
                  <% else %>
                    <%= for agent <- @fleet do %>
                      <tr class="hover:bg-gray-800/30 transition">
                        <td class="px-4 py-3 font-semibold text-white">
                          <%= agent.agent_id %>
                        </td>
                        <td class="px-4 py-3 text-cyan-300">
                          <%= agent.repository || "—" %>
                        </td>
                        <td class="px-4 py-3">
                          <span class={"inline-block px-2 py-0.5 rounded text-[10px] font-bold #{state_badge_class(agent.state)}"}>
                            ● <%= agent.state |> to_string() |> String.upcase() %>
                          </span>
                        </td>
                        <td class="px-4 py-3 text-gray-300">
                          <%= agent.last_activity %>
                        </td>
                        <td class="px-4 py-3 text-gray-400">
                          <%= agent.event_count %>
                        </td>
                        <td class="px-4 py-3">
                          <span class={"text-[10px] uppercase font-bold #{standing_text_class(agent.standing)}"}>
                            <%= agent.standing %>
                          </span>
                        </td>
                      </tr>
                    <% end %>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Live Discovered DFG (Directly-Follows Graph) -->
          <div class="bg-[#121829] border border-gray-800 rounded-xl p-5">
            <div class="flex items-center justify-between mb-4">
              <div>
                <h2 class="text-sm font-bold uppercase tracking-wider text-gray-200 font-mono">
                  Directly-Follows Process Graph (DFG)
                </h2>
                <p class="text-xs text-gray-400 mt-0.5">
                  Real-time transition matrix with frequency counts & median/mean handoff latencies.
                </p>
              </div>
              <span class="text-xs font-mono text-emerald-400 bg-emerald-950 px-2 py-1 rounded border border-emerald-900">
                <%= map_size(@dfg.edges) %> edges discovered
              </span>
            </div>

            <%= if map_size(@dfg.edges) == 0 do %>
              <div class="h-48 border border-dashed border-gray-800 rounded-lg flex items-center justify-center text-gray-500 font-mono text-xs">
                Awaiting process events to construct online DFG...
              </div>
            <% else %>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3 max-h-80 overflow-y-auto pr-1">
                <%= for {{from, to}, stats} <- @dfg.edges do %>
                  <div class="bg-[#0e1322] border border-gray-800/80 rounded-lg p-3 flex items-center justify-between">
                    <div class="space-y-1">
                      <div class="flex items-center space-x-2 text-xs font-mono font-medium text-gray-200">
                        <span class="text-emerald-400"><%= from %></span>
                        <span class="text-gray-500">→</span>
                        <span class="text-cyan-400"><%= to %></span>
                      </div>
                      <div class="text-[11px] font-mono text-gray-400">
                        Avg: <span class="text-amber-300"><%= Float.round(stats.average_duration_ms, 1) %> ms</span>
                        (Min: <%= stats.min_duration_ms %>ms / Max: <%= stats.max_duration_ms %>ms)
                      </div>
                    </div>
                    <div class="text-right font-mono">
                      <span class="inline-block px-2.5 py-1 rounded-full bg-emerald-950/80 text-emerald-300 border border-emerald-800 text-xs font-bold">
                        <%= stats.count %>x
                      </span>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <!-- Cognition & AutoSystems (wasm4pm Parity) -->
          <div class="bg-[#121829] border border-gray-800 rounded-xl overflow-hidden">
            <div class="px-5 py-3.5 border-b border-gray-800 flex items-center justify-between bg-[#151c30]">
              <h2 class="text-sm font-bold uppercase tracking-wider text-purple-300 flex items-center gap-2 font-mono">
                <span>🧠 Cognition & AutoSystems Breeds</span>
                <span class="text-xs text-purple-400 font-normal bg-purple-950/60 px-2 py-0.5 rounded border border-purple-800">60+ Breeds Active</span>
              </h2>
            </div>
            <div class="p-5 grid grid-cols-2 md:grid-cols-4 gap-3 font-mono text-xs">
              <div class="bg-[#0e1322] border border-gray-800 p-3 rounded space-y-1">
                <div class="text-[11px] text-gray-400 font-semibold">Bayesian Inference</div>
                <div class="text-emerald-400 font-bold">Exact & Belief Prop</div>
                <div class="text-[10px] text-gray-500">P(Q|E) variable elimination</div>
              </div>
              <div class="bg-[#0e1322] border border-gray-800 p-3 rounded space-y-1">
                <div class="text-[11px] text-gray-400 font-semibold">Prolog Resolution</div>
                <div class="text-cyan-400 font-bold">Horn-Clause Unify</div>
                <div class="text-[10px] text-gray-500">Robinson first-order logic</div>
              </div>
              <div class="bg-[#0e1322] border border-gray-800 p-3 rounded space-y-1">
                <div class="text-[11px] text-gray-400 font-semibold">STRIPS / HTN Plan</div>
                <div class="text-indigo-400 font-bold">Means-Ends Search</div>
                <div class="text-[10px] text-gray-500">Precondition/Add/Del state</div>
              </div>
              <div class="bg-[#0e1322] border border-gray-800 p-3 rounded space-y-1">
                <div class="text-[11px] text-gray-400 font-semibold">Temporal & LTL</div>
                <div class="text-amber-400 font-bold">Allen 13 Relations</div>
                <div class="text-[10px] text-gray-500">Trace formula model checking</div>
              </div>
              <div class="bg-[#0e1322] border border-gray-800 p-3 rounded space-y-1">
                <div class="text-[11px] text-gray-400 font-semibold">Pareto Dominance</div>
                <div class="text-pink-400 font-bold">Multi-Objective</div>
                <div class="text-[10px] text-gray-500">Fitness vs Cost frontiers</div>
              </div>
              <div class="bg-[#0e1322] border border-gray-800 p-3 rounded space-y-1">
                <div class="text-[11px] text-gray-400 font-semibold">AutoSystems Cost</div>
                <div class="text-yellow-400 font-bold">f(delay, risk, cu)</div>
                <div class="text-[10px] text-gray-500">Replacement cost evaluator</div>
              </div>
              <div class="bg-[#0e1322] border border-gray-800 p-3 rounded space-y-1">
                <div class="text-[11px] text-gray-400 font-semibold">Adversarial Audits</div>
                <div class="text-rose-400 font-bold">8 False-Pass Tests</div>
                <div class="text-[10px] text-gray-500">Anti-spoofing integrity</div>
              </div>
              <div class="bg-[#0e1322] border border-gray-800 p-3 rounded space-y-1">
                <div class="text-[11px] text-gray-400 font-semibold">InterviewAssist</div>
                <div class="text-teal-400 font-bold">Active Inquiry</div>
                <div class="text-[10px] text-gray-500">Agent qualification gates</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Right Col: Live Event Feed & Refusals -->
        <div class="space-y-8">
          <!-- Live Event Feed -->
          <div class="bg-[#121829] border border-gray-800 rounded-xl overflow-hidden">
            <div class="px-4 py-3 bg-[#151c30] border-b border-gray-800 flex items-center justify-between">
              <h2 class="text-xs font-bold uppercase tracking-wider text-gray-200 font-mono flex items-center gap-2">
                <span class="w-2 h-2 rounded-full bg-emerald-400 animate-ping"></span>
                <span>Streaming Event Ticker</span>
              </h2>
              <span class="text-[10px] font-mono text-gray-400">PubSub Connected</span>
            </div>

            <div class="p-3 max-h-72 overflow-y-auto space-y-2 font-mono text-xs">
              <%= if @live_events == [] do %>
                <div class="text-gray-500 text-center py-8 italic">
                  No live events streamed yet.
                </div>
              <% else %>
                <%= for ev <- @live_events do %>
                  <div class="bg-[#0e1322] border border-gray-800 p-2.5 rounded text-[11px] space-y-1">
                    <div class="flex items-center justify-between">
                      <span class="text-emerald-400 font-semibold"><%= ev.activity %></span>
                      <span class="text-[10px] text-gray-500"><%= String.slice(to_string(ev.timestamp), 11, 8) %></span>
                    </div>
                    <div class="text-gray-400 text-[10px] flex items-center justify-between">
                      <span>Agent: <span class="text-gray-300"><%= ev.agent_id %></span></span>
                      <span class="text-emerald-500 font-bold uppercase"><%= ev.standing %></span>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>

          <!-- Refusal Radar -->
          <div class="bg-[#121829] border border-gray-800 rounded-xl overflow-hidden">
            <div class="px-4 py-3 bg-[#151c30] border-b border-gray-800 flex items-center justify-between">
              <h2 class="text-xs font-bold uppercase tracking-wider text-rose-300 font-mono">
                🛡️ Refusal & BRCE Radar
              </h2>
              <span class="text-[10px] font-mono text-rose-400 bg-rose-950/60 px-1.5 py-0.5 rounded border border-rose-800">
                <%= length(@recent_refusals) %> denials
              </span>
            </div>

            <div class="p-3 max-h-60 overflow-y-auto space-y-2 font-mono text-xs">
              <%= if @recent_refusals == [] do %>
                <div class="text-gray-500 text-center py-6 italic text-[11px]">
                  No refusal events recorded. All executions admitted lawfully.
                </div>
              <% else %>
                <%= for refusal <- @recent_refusals do %>
                  <div class="bg-rose-950/20 border border-rose-900/60 p-2.5 rounded text-[11px] space-y-1">
                    <div class="flex items-center justify-between text-rose-400 font-semibold">
                      <span><%= refusal.code %></span>
                      <span class="text-[10px] text-gray-500"><%= String.slice(to_string(refusal.timestamp), 11, 8) %></span>
                    </div>
                    <div class="text-gray-300 text-[10px]">
                      <%= refusal.message %>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>

          <!-- Process Variants Distribution -->
          <div class="bg-[#121829] border border-gray-800 rounded-xl p-4">
            <h2 class="text-xs font-bold uppercase tracking-wider text-gray-200 font-mono mb-3">
              Top Process Variants
            </h2>
            <div class="space-y-2 max-h-48 overflow-y-auto font-mono text-[11px]">
              <%= if @variants == [] do %>
                <div class="text-gray-500 text-center py-4 italic">
                  No variants discovered yet.
                </div>
              <% else %>
                <%= for variant <- @variants do %>
                  <div class="bg-[#0e1322] border border-gray-800 p-2 rounded flex items-center justify-between">
                    <div class="truncate mr-2 text-gray-300">
                      <%= Enum.join(variant.path, " → ") %>
                    </div>
                    <span class="text-amber-400 font-bold bg-amber-950 px-1.5 py-0.5 rounded border border-amber-900 shrink-0">
                      <%= variant.count %>x
                    </span>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp state_badge_class(:executing),
    do: "bg-emerald-950 text-emerald-400 border border-emerald-800"

  defp state_badge_class(:verifying), do: "bg-cyan-950 text-cyan-400 border border-cyan-800"

  defp state_badge_class(:constructing),
    do: "bg-indigo-950 text-indigo-400 border border-indigo-800"

  defp state_badge_class(:refused), do: "bg-rose-950 text-rose-400 border border-rose-800"
  defp state_badge_class(:complete), do: "bg-gray-800 text-gray-400 border border-gray-700"
  defp state_badge_class(_), do: "bg-emerald-950 text-emerald-400 border border-emerald-800"

  defp standing_text_class(:alive), do: "text-emerald-400"
  defp standing_text_class(:partial_alive), do: "text-amber-400"
  defp standing_text_class(:blocked), do: "text-rose-400"
  defp standing_text_class(:refused), do: "text-rose-400"
  defp standing_text_class(_), do: "text-gray-400"
end
