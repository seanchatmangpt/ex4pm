defmodule Ex4pm.Engine.Beam4pmA2A do
  @moduledoc """
  Additive A2A.Client-based path to beam4pm, alongside (not replacing)
  `Ex4pm.Engine.Beam4pm`'s existing hand-rolled AshJsonApi route-table
  client.

  Explicit architectural constraint this module honors (per user
  directive): A2A is the agent-facing interface only, used here for
  cross-repo/agent traffic where it genuinely makes sense to compare
  against the existing route-table client later -- it does not deprecate
  or replace `Ex4pm.Engine.Beam4pm`, and no existing caller is migrated
  onto this path in this change. beam4pm's internal mechanisms (Ash
  domain internals, the EngineOp dispatch/telemetry pipeline, the
  OCEL/OTel evidence chain, `BeamPM.ReceiptChain`) are untouched --
  this module only ever talks to beam4pm's mounted `/a2a` agent-facing
  endpoint over A2A JSON-RPC, never any of those internals directly.

  Targets the real beam4pm A2A agent mounted at `/a2a` (see the
  companion beam4pm session: `BeamPM.A2ARouter` forwarding to
  `A2A.Plug` wrapping `BeamPM.A2AAgent`, an `AshA2A.Agent` over
  `BeamPM.Ash.Domain`, default port 4211). Exposes exactly the same 2
  curated skills already curated as `ash_ai` tools on the beam4pm side
  -- `read_ocel_events` (`BeamPM.Ash.Resources.OcelEvent`, action
  `:read`) and `read_conformance_results`
  (`BeamPM.Ash.Resources.ConformanceResult`, action `:read`). No
  additional beam4pm resources are exposed here; if a real reason to
  expose more surfaces later, it should be stated explicitly rather than
  silently expanding scope.

  Configure with `beam4pm_a2a_base_url: "http://host:port/a2a"` in opts
  (or `Application.put_env(:ex4pm, :beam4pm_a2a_base_url, ...)`).
  """

  alias Ex4pm.Refusal

  @skills %{
    beam4pm_ocel_events: "read_ocel_events",
    beam4pm_conformance_results: "read_conformance_results"
  }

  @doc "The 2 curated A2A skill ids this client can call."
  def skills, do: @skills

  @doc """
  Discovers the beam4pm A2A agent's real `AgentCard` at `base_url` via
  `A2A.Client.discover/2`.
  """
  @spec discover(String.t(), keyword()) :: {:ok, A2A.AgentCard.t()} | {:error, term()}
  def discover(base_url, opts \\ []) when is_binary(base_url) do
    A2A.Client.discover(base_url, opts)
  end

  @doc """
  Calls one of the 2 curated beam4pm A2A skills via
  `A2A.Client.send_message/3`, using `metadata: %{"skill" => skill_id}`
  to select the skill server-side (same convention beam4pm's real
  `AshA2A.Agent` dispatch uses).

  Returns `{:ok, %{task: A2A.Task.t(), data: [map()]}}` on a real
  `:completed` task whose artifact carries an `A2A.Part.Data` part, or a
  refusal otherwise -- never silently returns an empty/partial result as
  success.
  """
  @spec call_skill(atom(), keyword()) :: {:ok, %{task: A2A.Task.t(), data: term()}} | {:error, term()}
  def call_skill(operation, opts \\ []) do
    with skill when is_binary(skill) <-
           Map.get(@skills, operation) ||
             {:error,
              Refusal.new(:beam4pm_a2a_unsupported_operation, "no curated A2A skill for this operation",
                details: %{operation: operation}
              )},
         base when is_binary(base) <-
           base_url(opts) ||
             {:error,
              Refusal.new(:beam4pm_a2a_unavailable, "no beam4pm_a2a_base_url configured",
                details: %{operation: operation}
              )},
         {:ok, task} <-
           dispatch(base, skill, opts) do
      handle_task(task, operation, skill)
    end
  end

  defp dispatch(base, skill, opts) do
    case A2A.Client.send_message(base, "invoke #{skill}", metadata: %{"skill" => skill}, headers: opts[:headers] || []) do
      {:ok, task} ->
        {:ok, task}

      {:error, reason} ->
        {:error,
         Refusal.new(:beam4pm_a2a_unavailable, "beam4pm A2A request failed", details: %{reason: inspect(reason)})}
    end
  rescue
    e -> {:error, Refusal.new(:beam4pm_a2a_unavailable, "beam4pm A2A request failed", details: %{reason: inspect(e)})}
  catch
    :exit, reason ->
      {:error,
       Refusal.new(:beam4pm_a2a_unavailable, "beam4pm A2A request failed", details: %{reason: inspect(reason)})}
  end

  defp handle_task(%A2A.Task{status: %{state: :completed}} = task, _operation, _skill) do
    data =
      task.artifacts
      |> Enum.flat_map(& &1.parts)
      |> Enum.find_value(fn
        %A2A.Part.Data{data: data} -> data
        _ -> nil
      end)

    if is_map(data) do
      {:ok, %{task: task, data: data}}
    else
      {:error,
       Refusal.new(:beam4pm_a2a_invalid_response, "beam4pm A2A task completed with no structured data part",
         details: %{task_id: task.id}
       )}
    end
  end

  defp handle_task(%A2A.Task{status: %{state: state}} = task, operation, skill) do
    {:error,
     Refusal.new(:beam4pm_a2a_task_not_completed, "beam4pm A2A task did not complete",
       details: %{operation: operation, skill: skill, task_id: task.id, state: state}
     )}
  end

  defp base_url(opts) do
    Keyword.get(opts, :beam4pm_a2a_base_url) || Application.get_env(:ex4pm, :beam4pm_a2a_base_url)
  end
end
