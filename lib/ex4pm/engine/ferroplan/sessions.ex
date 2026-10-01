defmodule Ex4pm.Engine.Ferroplan.Sessions do
  @moduledoc """
  Facade over ferroplan's 28 stateful `session_*` ABI ops.

  Each session is an isolated `Ex4pm.Engine.Ferroplan.Session` process owning
  its own wasm instance and guest handle (see that module). The caller holds an
  opaque string `session_id`; the integer guest handle is injected by the
  process and never exposed.

  Every function returns `{:ok, map}` or `{:error, %Ex4pm.Refusal{}}`.
  Responses that ferroplan encodes as a bare JSON array or null
  (`observe`, `elapse`, `suffix`, `step`) are wrapped as `%{"value" => json}`.

  Authority: all session ops are CONSTRUCT-only. `repair`, `think`,
  `replan_following` and `probe` manufacture candidate plans; none actuates.
  State-changing DO remains exclusively behind `Ex4pm.Evidence.BRCE`.

  Options (`new/3`): `:ferroplan_artifact`, `:ferroplan_expected_sha256`
  (same meaning as for `Ex4pm.Engine.Ferroplan`), `:timeout` (per call, ms),
  `:session_id`.

  Refusal codes added here: `:ferroplan_session_not_found`,
  `:ferroplan_session_unknown_op`, `:ferroplan_session_instance_lost`,
  `:ferroplan_session_replay_failed`, `:ferroplan_session_boot_failed`.
  """

  alias Ex4pm.Refusal
  alias Ex4pm.Engine.Ferroplan.Session
  alias Ex4pm.Engine.Ferroplan.SessionSupervisor

  @type session_id :: String.t()
  @type result :: {:ok, map()} | {:error, Refusal.t()}

  @default_evals 10_000
  @default_mem_mb 64

  @doc """
  Idempotently ensure the session supervision tree is running. A no-op when
  `Ex4pm.Engine.Ferroplan.SessionSupervisor` is already supervised by the
  application; otherwise started unlinked from the caller.
  """
  @spec ensure_started() :: :ok | {:error, Refusal.t()}
  def ensure_started do
    case Process.whereis(SessionSupervisor) do
      pid when is_pid(pid) ->
        :ok

      nil ->
        case SessionSupervisor.start_link([]) do
          {:ok, pid} ->
            Process.unlink(pid)
            :ok

          {:error, {:already_started, _}} ->
            :ok

          {:error, reason} ->
            {:error,
             Refusal.new(:ferroplan_session_boot_failed, "session supervisor failed to start",
               details: %{reason: inspect(reason)}
             )}
        end
    end
  end

  # -- lifecycle -------------------------------------------------------------

  @doc "Create a session on PDDL `domain_pddl` / `problem_pddl`."
  @spec new(binary(), binary(), keyword()) :: {:ok, session_id()} | {:error, Refusal.t()}
  def new(domain_pddl, problem_pddl, opts \\ [])

  def new(domain, problem, opts) when is_binary(domain) and is_binary(problem) do
    start_session(
      id: Keyword.get_lazy(opts, :session_id, &new_id/0),
      domain: domain,
      problem: problem,
      opts: Keyword.delete(opts, :session_id)
    )
  end

  def new(d, p, _opts) do
    {:error,
     Refusal.new(:ferroplan_bad_input, "session domain/problem must be PDDL binaries",
       details: %{domain: inspect(d, limit: 3), problem: inspect(p, limit: 3)}
     )}
  end

  @doc """
  Fork into a new, independent session (own wasm instance) by replaying the
  parent's journal. `keep_plan: true` keeps the stashed plan and cursor;
  default drops the plan, matching the ABI's `session_fork`.
  """
  @spec fork(session_id(), keyword()) :: {:ok, session_id()} | {:error, Refusal.t()}
  def fork(session_id, opts \\ []) do
    with {:ok, pid} <- lookup(session_id) do
      spec = GenServer.call(pid, :fork_spec, 30_000)
      keep? = Keyword.get(opts, :keep_plan, false)
      journal = if keep?, do: spec.journal, else: spec.journal ++ [{"drop_plan", %{}}]

      start_session(
        id: Keyword.get_lazy(opts, :session_id, &new_id/0),
        domain: spec.domain,
        problem: spec.problem,
        opts: spec.opts,
        journal: journal,
        origin: {:fork_of, session_id}
      )
    end
  catch
    :exit, _ -> not_found(session_id)
  end

  @doc "Free the guest session, stop its wasm instance and terminate the process."
  @spec free(session_id()) :: result()
  def free(session_id) do
    with {:ok, pid} <- lookup(session_id) do
      GenServer.call(pid, :free, 30_000)
    end
  catch
    :exit, _ -> not_found(session_id)
  end

  @doc """
  Rebuild a session whose wasm instance died (trap, timeout, kill): start a
  fresh instance, `session_new`, replay the journal. Returns the session info.
  """
  @spec recover(session_id()) :: result()
  def recover(session_id) do
    with {:ok, pid} <- lookup(session_id) do
      case GenServer.call(pid, :recover, 120_000) do
        {:ok, info} -> {:ok, Map.drop(info, [:handle])}
        {:error, _} = err -> err
      end
    end
  catch
    :exit, _ -> not_found(session_id)
  end

  @doc "Diagnostic info (`:transport` pid, `:handle`, `:instance_lost`, `:journal_length`)."
  @spec info(session_id()) :: {:ok, map()} | {:error, Refusal.t()}
  def info(session_id) do
    with {:ok, pid} <- lookup(session_id) do
      {:ok, GenServer.call(pid, :info, 30_000)}
    end
  catch
    :exit, _ -> not_found(session_id)
  end

  @doc "Ids of all live sessions."
  @spec list() :: [session_id()]
  def list do
    Registry.select(SessionSupervisor.registry(), [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.sort()
  rescue
    ArgumentError -> []
  end

  # -- generic op ------------------------------------------------------------

  @doc """
  Run session op `op` (atom or string, with or without the `session_` prefix,
  e.g. `:set_goal`) with `args` (map; atom or string keys, tuples become JSON
  arrays). The handle is injected. `new`/`fork`/`free` are lifecycle ops, see
  `new/3`, `fork/2`, `free/1`.
  """
  @spec call(session_id(), atom() | String.t(), map(), keyword()) :: result()
  def call(session_id, op, args \\ %{}, opts \\ []) when is_map(args) do
    case normalize_op(op) do
      {:ok, "free"} ->
        free(session_id)

      {:ok, "fork"} ->
        with {:ok, id} <- fork(session_id, keep_plan: truthy(args, "keep_plan")),
             do: {:ok, %{"session_id" => id}}

      {:ok, "new"} ->
        {:error, unknown_op(op, "use Sessions.new/3 to create a session")}

      {:ok, op} ->
        with {:ok, pid} <- lookup(session_id) do
          timeout = Keyword.get(opts, :timeout, 30_000)
          GenServer.call(pid, {:op, op, jsonable(args), opts}, timeout + 10_000)
        end

      :error ->
        {:error, unknown_op(op, nil)}
    end
  catch
    :exit, _ -> not_found(session_id)
  end

  # -- convenience -----------------------------------------------------------

  @doc "Apply `[{fact, bool}]` sensor observations; returns `%{\"value\" => surprises}`."
  @spec observe(session_id(), [{String.t(), boolean()}] | [[term()]]) :: result()
  def observe(session_id, sight), do: call(session_id, :observe, %{sight: sight})

  @doc "Plan from the session's current belief. Opts `:evals`, `:mem_mb`, `:prefer_follow`."
  @spec think(session_id(), keyword()) :: result()
  def think(session_id, opts \\ []) do
    args =
      budget(opts) |> Map.put("prefer_follow", Keyword.get(opts, :prefer_follow, false))

    call(session_id, :think, args, Keyword.take(opts, [:timeout]))
  end

  @doc "Whether the stashed plan is still valid from the cursor (`session_valid`)."
  @spec plan_valid?(session_id()) :: result()
  def plan_valid?(session_id), do: call(session_id, :valid)

  @doc "DfCM repair router (reuse valid suffix, else follow-biased replan, else full replan)."
  @spec repair(session_id(), keyword()) :: result()
  def repair(session_id, opts \\ []),
    do: call(session_id, :repair, budget(opts), Keyword.take(opts, [:timeout]))

  @doc "Follow-before-rethink over the stashed plan."
  @spec replan_following(session_id(), keyword()) :: result()
  def replan_following(session_id, opts \\ []),
    do: call(session_id, :replan_following, budget(opts), Keyword.take(opts, [:timeout]))

  @doc "Evaluate counterfactual forks (`candidates`: `[%{id:, goal:, sight:}]`) without mutating the session."
  @spec probe(session_id(), [map()], keyword()) :: result()
  def probe(session_id, candidates, opts \\ []) when is_list(candidates),
    do:
      call(
        session_id,
        :probe,
        Map.put(budget(opts), "candidates", candidates),
        Keyword.take(opts, [:timeout])
      )

  @doc "Remaining plan steps from the cursor: `%{\"value\" => steps}`."
  @spec suffix(session_id()) :: result()
  def suffix(session_id), do: call(session_id, :suffix)

  @doc "Move the plan cursor one step (the guest's model only; BRCE owns real execution)."
  @spec advance(session_id()) :: result()
  def advance(session_id), do: call(session_id, :advance)

  @doc "Whether the goal currently holds in the session's belief."
  @spec goal_met?(session_id()) :: result()
  def goal_met?(session_id), do: call(session_id, :goal_met)

  # -- helpers ---------------------------------------------------------------

  defp start_session(args) do
    with :ok <- ensure_started() do
      case DynamicSupervisor.start_child(SessionSupervisor.dynamic(), {Session, args}) do
        {:ok, pid} ->
          case GenServer.call(pid, :await_ready, 120_000) do
            :ok -> {:ok, args[:id]}
            {:error, %Refusal{}} = err -> err
          end

        {:error, reason} ->
          {:error,
           Refusal.new(:ferroplan_session_boot_failed, "session process failed to start",
             details: %{reason: inspect(reason)}
           )}
      end
    end
  catch
    :exit, reason ->
      {:error,
       Refusal.new(:ferroplan_session_boot_failed, "session boot exited",
         details: %{reason: inspect(reason)}
       )}
  end

  defp lookup(session_id) do
    case is_binary(session_id) and Session.whereis(session_id) do
      pid when is_pid(pid) -> {:ok, pid}
      _ -> not_found(session_id)
    end
  end

  defp not_found(session_id) do
    {:error,
     Refusal.new(:ferroplan_session_not_found, "no live ferroplan session with that id",
       subject: session_id
     )}
  end

  defp unknown_op(op, hint) do
    Refusal.new(:ferroplan_session_unknown_op, "unknown ferroplan session op",
      subject: op,
      details: %{supported: Session.ops(), hint: hint}
    )
  end

  defp normalize_op(op) when is_atom(op) and not is_nil(op), do: normalize_op(Atom.to_string(op))

  defp normalize_op(op) when is_binary(op) do
    name = String.replace_prefix(op, "session_", "")
    if name in Session.ops(), do: {:ok, name}, else: :error
  end

  defp normalize_op(_), do: :error

  defp truthy(args, key),
    do: Map.get(args, key) == true or Map.get(args, String.to_atom(key)) == true

  defp budget(opts) do
    %{
      "evals" => Keyword.get(opts, :evals, @default_evals),
      "mem_mb" => Keyword.get(opts, :mem_mb, @default_mem_mb)
    }
  end

  defp new_id, do: "fps_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)

  # JSON-ready, string-keyed: tuples -> arrays, atom keys/values -> strings.
  defp jsonable(%{} = map),
    do: Map.new(map, fn {k, v} -> {to_string(k), jsonable(v)} end)

  defp jsonable(list) when is_list(list), do: Enum.map(list, &jsonable/1)
  defp jsonable(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> jsonable()
  defp jsonable(v) when is_boolean(v) or is_nil(v), do: v
  defp jsonable(v) when is_atom(v), do: Atom.to_string(v)
  defp jsonable(v), do: v
end
