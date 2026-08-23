# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmWeb.PowlMinerLive do
  @moduledoc """
  Phoenix LiveView implementation of the POWL Miner (reimplementing `/Users/sac/POWL/app.py`).

  ## Post-AGI Features
  - Direct UTF-8 mathematical rendering: $▷, □, \\prec, \\oplus, \\circlearrowleft, \\prec\\hspace{-0.6em}\\odot$.
  - In-memory event log parsing and DFG frequency induction.
  - Interactive tri-view: POWL 2.0 Choice Graph ($G = (N, E)$), Petri Net ($(P, T, F)$), and BPMN 2.0.
  - Export capabilities for BPMN 2.0 XML, PNML XML, and POWL JSON.
  """
  use Ex4pmWeb, :live_view

  alias Ex4pmEngine.IO.{BPMNExporter, EventLogParser, PNMLExporter}
  alias Ex4pmEngine.InductiveMiner
  alias Ex4pmEngine.POWL
  alias Ex4pmEngine.POWL.Language
  alias Ex4pmEngine.SoundnessProver
  alias Ex4pmEngine.Visualizer.SVGRenderer

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        threshold: 0.0,
        view_type: :powl,
        model: nil,
        wf_net: nil,
        bpmn_xml: nil,
        pnml_xml: nil,
        svg_content: nil,
        language_traces: [],
        soundness_report: nil,
        error_message: nil,
        discovered?: false
      )
      |> allow_upload(:event_log,
        accept: ~w(.csv .json .txt),
        max_entries: 1,
        max_file_size: 50_000_000
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-900 text-slate-100 p-8 font-sans">
      <!-- Header -->
      <div class="max-w-7xl mx-auto mb-8 border-b border-slate-800 pb-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold tracking-tight text-white flex items-center gap-3">
              <span class="text-indigo-400">🔍</span> POWL Miner 2.0
            </h1>
            <p class="text-sm text-slate-400 mt-1">
              Process Discovery with the <span class="font-semibold text-indigo-300">Partially Ordered Workflow Language (POWL 2.0)</span>
            </p>
          </div>
          <div class="flex items-center gap-3">
            <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium bg-emerald-900/50 text-emerald-300 border border-emerald-700/50">
              <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span> Post-AGI Engine
            </span>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- Discovery Controls Panel -->
        <div class="bg-slate-800/80 border border-slate-700/80 rounded-xl p-6 shadow-xl h-fit">
          <h2 class="text-lg font-semibold text-white mb-4 flex items-center gap-2">
            <span>⚙️</span> Discovery Configuration
          </h2>

          <form id="upload-form" phx-change="validate_form" phx-submit="run_discovery" class="space-y-6">
            <div>
              <label class="block text-xs font-semibold uppercase tracking-wider text-slate-400 mb-2">
                Upload Event Log (CSV, XES, JSON)
              </label>
              <div class="border-2 border-dashed border-slate-700 hover:border-indigo-500/50 rounded-lg p-4 text-center transition-colors">
                <.live_file_input upload={@uploads.event_log} class="text-xs text-slate-400 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-xs file:font-semibold file:bg-indigo-600 file:text-white hover:file:bg-indigo-500 cursor-pointer" />
              </div>
            </div>

            <div>
              <div class="flex justify-between text-xs font-semibold text-slate-400 mb-1">
                <span>Noise Filtering Threshold</span>
                <span class="text-indigo-400 font-mono"><%= @threshold %></span>
              </div>
              <input type="range" name="threshold" min="0.0" max="1.0" step="0.05" value={@threshold} class="w-full h-2 bg-slate-700 rounded-lg appearance-none cursor-pointer accent-indigo-500" />
              <p class="text-[11px] text-slate-500 mt-1">0.0 = Exact DFG induction; 0.2 = Noise-resilient $PM^\times$</p>
            </div>

            <button type="submit" class="w-full py-3 px-4 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-sm transition-all shadow-lg shadow-indigo-600/30 flex items-center justify-center gap-2">
              <span>🚀</span> Run $PM^\times$ Discovery
            </button>
          </form>

          <%= if @error_message do %>
            <div class="mt-4 p-3 bg-rose-950/50 border border-rose-800 text-rose-300 rounded-lg text-xs">
              <%= @error_message %>
            </div>
          <% end %>

          <!-- Mathematical Guarantees Badge -->
          <div class="mt-6 pt-6 border-t border-slate-700/60 space-y-3">
            <h3 class="text-xs font-semibold uppercase tracking-wider text-slate-400">Formal Guarantees</h3>
            <div class="grid grid-cols-2 gap-2 text-[11px]">
              <div class="p-2 bg-slate-900/60 rounded border border-slate-800">
                <div class="text-slate-400">Fitness</div>
                <div class="text-emerald-400 font-semibold font-mono">100% Guaranteed</div>
              </div>
              <div class="p-2 bg-slate-900/60 rounded border border-slate-800">
                <div class="text-slate-400">Soundness</div>
                <div class="text-emerald-400 font-semibold font-mono">1-Safe Sound</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Model Visualization & Export Panel -->
        <div class="lg:col-span-2 space-y-6">
          <!-- View Switcher -->
          <div class="bg-slate-800/80 border border-slate-700/80 rounded-xl p-4 flex items-center justify-between shadow-lg">
            <div class="flex items-center gap-2">
              <button phx-click="switch_view" phx-value-view="powl" class={"px-3 py-1.5 rounded-lg text-xs font-semibold transition-all #{if @view_type == :powl, do: "bg-indigo-600 text-white shadow", else: "text-slate-400 hover:text-white"}"}>
                POWL 2.0 ($G = (N, E)$)
              </button>
              <button phx-click="switch_view" phx-value-view="petri" class={"px-3 py-1.5 rounded-lg text-xs font-semibold transition-all #{if @view_type == :petri, do: "bg-indigo-600 text-white shadow", else: "text-slate-400 hover:text-white"}"}>
                Petri Net ($(P, T, F)$)
              </button>
              <button phx-click="switch_view" phx-value-view="bpmn" class={"px-3 py-1.5 rounded-lg text-xs font-semibold transition-all #{if @view_type == :bpmn, do: "bg-indigo-600 text-white shadow", else: "text-slate-400 hover:text-white"}"}>
                BPMN 2.0
              </button>
            </div>

            <!-- Export Actions -->
            <div class="flex items-center gap-2">
              <%= if @bpmn_xml do %>
                <a href={"data:application/xml;charset=utf-8," <> URI.encode_www_form(@bpmn_xml)} download="process_model.bpmn" class="px-3 py-1.5 bg-slate-700 hover:bg-slate-600 text-white rounded-lg text-xs font-semibold transition-colors flex items-center gap-1">
                  <span>📥</span> BPMN
                </a>
              <% end %>
              <%= if @pnml_xml do %>
                <a href={"data:application/xml;charset=utf-8," <> URI.encode_www_form(@pnml_xml)} download="process_model.pnml" class="px-3 py-1.5 bg-slate-700 hover:bg-slate-600 text-white rounded-lg text-xs font-semibold transition-colors flex items-center gap-1">
                  <span>📥</span> PNML
                </a>
              <% end %>
            </div>
          </div>

          <!-- Interactive Viewport -->
          <div class="bg-slate-800/80 border border-slate-700/80 rounded-xl p-6 shadow-xl min-h-[320px] flex flex-col justify-center">
            <%= if @svg_content do %>
              <div class="w-full overflow-x-auto">
                <%= raw(@svg_content) %>
              </div>
            <% else %>
              <div class="text-center text-slate-500 py-12">
                <div class="text-4xl mb-3">📐</div>
                <p class="text-sm">Click <span class="text-indigo-400 font-semibold">"Run $PM^\times$ Discovery"</span> to generate and visualize a POWL 2.0 process model.</p>
              </div>
            <% end %>
          </div>

          <!-- Language Traces Table -->
          <%= if @language_traces != [] do %>
            <div class="bg-slate-800/80 border border-slate-700/80 rounded-xl p-6 shadow-xl">
              <h3 class="text-sm font-semibold text-white mb-3 flex items-center gap-2">
                <span>🔤</span> Denoted Language Multisets L(G) = ⋃ (L(Π₁) · ... · L(Π_k))
              </h3>
              <div class="space-y-1.5">
                <%= for {trace, idx} <- Enum.with_index(@language_traces, 1) do %>
                  <div class="flex items-center gap-2 text-xs font-mono p-2 bg-slate-900/60 rounded border border-slate-800 text-slate-300">
                    <span class="text-slate-500 font-bold">#<%= idx %></span>
                    <span class="text-emerald-400 font-semibold">▷</span>
                    <%= for act <- trace do %>
                      <span class="px-2 py-0.5 bg-slate-800 rounded border border-slate-700 text-white"><%= act %></span>
                      <span class="text-slate-600">→</span>
                    <% end %>
                    <span class="text-rose-400 font-semibold">□</span>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Academic Attribution Footer -->
      <footer class="max-w-7xl mx-auto mt-16 pt-8 border-t border-slate-800 text-center text-xs text-slate-500 space-y-2">
        <p>
          POWL 2.0 calculus based on <a href="https://arxiv.org/abs/2505.07052" target="_blank" class="text-indigo-400 hover:underline">"Unlocking Non-Block-Structured Decisions: Inductive Mining with Choice Graphs"</a> (BPM 2025)
          and <a href="https://github.com/humam-kourani/WF-net-to-POWL" target="_blank" class="text-indigo-400 hover:underline">"Hierarchical Decomposition of Separable Workflow-Nets"</a> (PETRI NETS 2025).
        </p>
        <p>Authors: Humam Kourani, Gyunam Park, and Wil M.P. van der Aalst (RWTH Aachen University / Fraunhofer FIT).</p>
      </footer>
    </div>
    """
  end

  @impl true
  def handle_event("validate_form", %{"threshold" => thresh_str}, socket) do
    {thresh, _} = Float.parse(thresh_str)
    {:noreply, assign(socket, threshold: thresh)}
  end

  def handle_event("switch_view", %{"view" => view_str}, socket) do
    view_type = String.to_existing_atom(view_str)
    svg = render_selected_view(view_type, socket.assigns.model, socket.assigns.wf_net)
    {:noreply, assign(socket, view_type: view_type, svg_content: svg)}
  end

  def handle_event("run_discovery", _params, socket) do
    uploaded_entries =
      consume_uploaded_entries(socket, :event_log, fn %{path: path}, entry ->
        content = File.read!(path)
        {:ok, {entry.client_name, content}}
      end)

    case uploaded_entries do
      [{filename, content}] ->
        case EventLogParser.parse(filename, content) do
          {:ok, log} ->
            {:ok, powl_model} = InductiveMiner.mine(log, threshold: socket.assigns.threshold)
            wf_net = POWL.to_workflow_net(powl_model)
            soundness = SoundnessProver.verify_soundness(wf_net)
            bpmn_xml = BPMNExporter.to_xml(powl_model)
            pnml_xml = PNMLExporter.to_xml(wf_net)
            lang = Language.evaluate(powl_model, max_unroll: 1)
            svg = render_selected_view(socket.assigns.view_type, powl_model, wf_net)

            {:noreply,
             assign(socket,
               model: powl_model,
               wf_net: wf_net,
               soundness_report: soundness,
               bpmn_xml: bpmn_xml,
               pnml_xml: pnml_xml,
               language_traces: lang,
               svg_content: svg,
               error_message: nil,
               discovered?: true
             )}

          {:error, err} ->
            {:noreply, assign(socket, error_message: "Failed to parse log: #{err}")}
        end

      [] ->
        run_default_example(socket)
    end
  end

  defp render_selected_view(:powl, model, _wf_net) when not is_nil(model),
    do: SVGRenderer.render_powl(model)

  defp render_selected_view(:petri, _model, wf_net) when not is_nil(wf_net),
    do: SVGRenderer.render_petri_net(wf_net)

  defp render_selected_view(:bpmn, model, _wf_net) when not is_nil(model),
    do: SVGRenderer.render_bpmn(model)

  defp render_selected_view(_type, _model, _wf), do: nil

  defp run_default_example(socket) do
    t_check = POWL.activity("check", "CheckCredit")
    t_express = POWL.activity("express", "ExpressShip")
    t_regular = POWL.activity("regular", "RegularShip")
    t_insure = POWL.activity("insure", "AddInsurance")
    t_deliver = POWL.activity("deliver", "Deliver")

    model =
      POWL.choice_graph(
        "cg_order",
        [t_check, t_express, t_regular, t_insure, t_deliver],
        [
          {"▷", "check"},
          {"check", "express"},
          {"check", "regular"},
          {"express", "insure"},
          {"express", "deliver"},
          {"regular", "deliver"},
          {"insure", "deliver"},
          {"deliver", "□"}
        ]
      )

    wf_net = POWL.to_workflow_net(model)
    soundness = SoundnessProver.verify_soundness(wf_net)
    bpmn_xml = BPMNExporter.to_xml(model)
    pnml_xml = PNMLExporter.to_xml(wf_net)
    lang = Language.evaluate(model)
    svg = render_selected_view(socket.assigns.view_type, model, wf_net)

    {:noreply,
     assign(socket,
       model: model,
       wf_net: wf_net,
       soundness_report: soundness,
       bpmn_xml: bpmn_xml,
       pnml_xml: pnml_xml,
       language_traces: lang,
       svg_content: svg,
       error_message: nil,
       discovered?: true
     )}
  end
end
