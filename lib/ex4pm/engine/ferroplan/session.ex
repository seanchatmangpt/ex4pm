defmodule Ex4pm.Engine.Ferroplan.Session do
  @moduledoc """
  One ferroplan planning session = one GenServer = one dedicated wasm
  instance (`Ex4pmEngine.Wasm.FerroplanTransport`) + one guest `u64` handle.

  Ferroplan keeps sessions in a process-global map inside a wasm instance, so
  sharing an instance across logical users would make handles collide and a
  timeout/trap would destroy everyone's sessions. Here every session owns its
  instance: a failure kills only that session's instance, and the caller never
  sees the integer handle.

  State kept for recovery: `domain`, `problem` and a journal of every
  successful state-changing op (goal/restrictions, facts, observations,
  think/repair, cursor moves). `recover/1` starts a fresh instance, re-creates
  the guest session and replays the journal, which is deterministic.

  Authority: every session op is CONSTRUCT-only. `repair`/`replan` manufacture
  and stash candidate plans; `advance`/`apply_start` move the guest's own
  model of the world. Nothing here actuates; DO stays with
  `Ex4pm.Evidence.BRCE`.

  Use `Ex4pm.Engine.Ferroplan.Sessions`; this module is its process.
  """
  use GenServer, restart: :temporary

  import Bitwise

  alias Ex4pm.Refusal
  alias Ex4pm.Engine.Ferroplan
  alias Ex4pm.Engine.Ferroplan.SessionSupervisor
  alias Ex4pmEngine.Wasm.FerroplanTransport

  @default_timeout 30_000

  # ops that change guest state and are replayed on recovery
  @mutating ~w(set_goal restrict_prefix_claims restrict_contains think replan_following
               repair advance drop_plan set_fact set_timed_fact observe apply_start elapse
               set_fluent)
  @readonly ~w(probe valid step suffix has_plan goal_met fact fluent plan_valid world_bytes
               mind_bytes)
  # lifecycle ops are handled by Sessions (new/fork) or this process (free)
  @lifecycle ~w(new fork free)

  @doc "All 28 session op names (without the `session_` prefix)."
  @spec ops() :: [String.t()]
  def ops, do: @lifecycle ++ @mutating ++ @readonly

  @doc false
  def mutating?(op), do: op in @mutating

  # responses that are JSON arrays / null: the transport only admits objects,
  # so these go through `raw_call/4` and are wrapped as `%{"value" => json}`
  @non_object ~w(observe elapse step suffix)

  # -- client API ------------------------------------------------------------

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via(Keyword.fetch!(args, :id)))
  end

  @doc false
  def via(id), do: {:via, Registry, {SessionSupervisor.registry(), id}}

  @doc false
  def whereis(id) do
    case Registry.lookup(SessionSupervisor.registry(), id) do
      [{pid, _}] -> pid
      _ -> nil
    end
  rescue
    ArgumentError -> nil
  end

  # -- GenServer -------------------------------------------------------------

  @impl true
  def init(args) do
    Process.flag(:trap_exit, true)

    state = %{
      id: Keyword.fetch!(args, :id),
      domain: Keyword.fetch!(args, :domain),
      problem: Keyword.fetch!(args, :problem),
      opts: Keyword.get(args, :opts, []),
      journal: Enum.reverse(Keyword.get(args, :journal, [])),
      transport: nil,
      handle: nil,
      freed: false,
      boot_error: nil,
      origin: Keyword.get(args, :origin)
    }

    {:ok, state, {:continue, :boot}}
  end

  @impl true
  def handle_continue(:boot, state) do
    case boot(state) do
      {:ok, state} -> {:noreply, state}
      {:error, refusal, state} -> {:noreply, %{state | boot_error: refusal}}
    end
  end

  @impl true
  def handle_call(:await_ready, _from, %{boot_error: nil} = state), do: {:reply, :ok, state}

  def handle_call(:await_ready, _from, %{boot_error: refusal} = state) do
    {:stop, :normal, {:error, refusal}, %{state | freed: true}}
  end

  def handle_call({:op, op, args, call_opts}, _from, state) do
    state = refresh_transport(state)

    case run_op(op, args, call_opts, state) do
      {:ok, reply, state} -> {:reply, {:ok, reply}, state}
      {:error, refusal, state} -> {:reply, {:error, refusal}, refresh_transport(state)}
    end
  end

  def handle_call(:free, _from, state) do
    state = refresh_transport(state)

    result =
      case state.transport do
        nil ->
          {:ok, %{"freed" => true, "instance_lost" => true}}

        _ ->
          case guest(state, "free", %{}, []) do
            {:ok, %{"freed" => true} = r} -> {:ok, r}
            {:error, refusal} -> {:error, refusal}
          end
      end

    {:stop, :normal, result, state}
  end

  def handle_call(:recover, _from, state) do
    stop_transport(state)
    state = %{state | transport: nil, handle: nil}

    case boot(state) do
      {:ok, state} -> {:reply, {:ok, info(state)}, state}
      {:error, refusal, state} -> {:reply, {:error, refusal}, state}
    end
  end

  def handle_call(:info, _from, state), do: {:reply, info(state), refresh_transport(state)}

  def handle_call(:fork_spec, _from, state) do
    {:reply,
     %{
       domain: state.domain,
       problem: state.problem,
       opts: state.opts,
       journal: Enum.reverse(state.journal)
     }, state}
  end

  @impl true
  def handle_info({:EXIT, pid, _reason}, %{transport: pid} = state),
    do: {:noreply, %{state | transport: nil}}

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    unless state.freed do
      if is_pid(state.transport) and Process.alive?(state.transport) and state.handle do
        _ = guest(state, "free", %{}, timeout: 5_000)
      end
    end

    stop_transport(state)
    :ok
  end

  # -- internals -------------------------------------------------------------

  defp info(state) do
    %{
      id: state.id,
      handle: state.handle,
      transport: state.transport,
      instance_lost: state.transport == nil,
      journal_length: length(state.journal),
      origin: state.origin
    }
  end

  defp refresh_transport(%{transport: pid} = state) when is_pid(pid) do
    if Process.alive?(pid), do: state, else: %{state | transport: nil}
  end

  defp refresh_transport(state), do: state

  defp stop_transport(%{transport: pid}) when is_pid(pid), do: FerroplanTransport.stop(pid)
  defp stop_transport(_), do: :ok

  defp boot(state) do
    artifact = Ferroplan.artifact_path(state.opts)

    case FerroplanTransport.start(artifact, transport_opts(state.opts)) do
      {:ok, pid} ->
        state = %{state | transport: pid}

        case boot_guest(state) do
          {:ok, state} -> {:ok, state}
          {:error, refusal} -> {:error, refusal, discard(state)}
        end

      {:error, %Refusal{} = refusal} ->
        {:error, refusal, state}
    end
  end

  defp boot_guest(state) do
    request = %{"domain" => state.domain, "problem" => state.problem}

    case FerroplanTransport.call(
           state.transport,
           "session_new",
           request,
           call_opts(state.opts)
         ) do
      {:ok, %{"handle" => handle}} ->
        replay(%{state | handle: handle})

      {:ok, other} ->
        {:error, Refusal.new(:ferroplan_bad_response, "no handle", details: %{result: other})}

      {:error, _} = err ->
        err
    end
  end

  defp discard(state) do
    stop_transport(state)
    %{state | transport: nil, handle: nil}
  end

  defp replay(state) do
    Enum.reduce_while(Enum.reverse(state.journal), {:ok, state}, fn {op, req}, acc ->
      case guest(state, op, req, call_opts(state.opts)) do
        {:ok, _} ->
          {:cont, acc}

        {:error, cause} ->
          {:halt,
           {:error,
            Refusal.new(:ferroplan_session_replay_failed, "journal replay failed",
              details: %{op: op, cause: cause}
            )}}
      end
    end)
  end

  defp transport_opts(opts) do
    case Keyword.fetch(opts, :ferroplan_expected_sha256) do
      {:ok, pin} -> [expected_sha256: pin]
      :error -> []
    end
  end

  defp call_opts(opts), do: Keyword.take(opts, [:timeout])

  defp run_op(op, args, call_opts, state) do
    cond do
      state.transport == nil ->
        {:error,
         Refusal.new(
           :ferroplan_session_instance_lost,
           "session wasm instance is gone; call recover/1 to rebuild from the journal",
           subject: state.id,
           details: %{journal_length: length(state.journal)}
         ), state}

      true ->
        merged = Keyword.merge(call_opts(state.opts), call_opts)
        t0 = System.monotonic_time()
        result = guest(state, op, args, merged)

        :telemetry.execute(
          [:ex4pm, :engine, :ferroplan, :session, String.to_atom(op)],
          %{duration: System.monotonic_time() - t0},
          %{ok: match?({:ok, _}, result), session: state.id}
        )

        case result do
          {:ok, reply} ->
            {:ok, reply, journal(state, op, args)}

          {:error, refusal} ->
            {:error, refusal, state}
        end
    end
  end

  defp journal(state, op, args) do
    if op in @mutating, do: %{state | journal: [{op, args} | state.journal]}, else: state
  end

  # One guest call with the session handle injected.
  defp guest(state, op, args, call_opts) do
    request = Map.put(args, "handle", state.handle)
    wire = "session_" <> op

    if op in @non_object do
      raw_call(state.transport, wire, request, call_opts)
    else
      FerroplanTransport.call(state.transport, wire, request, call_opts)
    end
  end

  # -- raw ABI call for non-object responses --------------------------------
  # Same wire sequence as FerroplanTransport.call/4 (alloc, write, fp_call,
  # read, dealloc the response). Needed because the transport refuses JSON
  # arrays / null (`session_observe`, `session_elapse`, `session_suffix`,
  # `session_step`); the result is wrapped as `%{"value" => decoded}`.

  defp raw_call(pid, op, request, opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    data = Jason.encode!(Map.put(request, "op", op))

    with {:ok, store} <- Wasmex.store(pid),
         {:ok, memory} <- Wasmex.memory(pid),
         {:ok, [raw]} <- Wasmex.call_function(pid, "fp_alloc", [byte_size(data)], timeout),
         ptr = band(raw, 0xFFFF_FFFF),
         true <- ptr != 0,
         :ok <- Wasmex.Memory.write_binary(store, memory, ptr, data),
         {:ok, [packed]} <- Wasmex.call_function(pid, "fp_call", [ptr, byte_size(data)], timeout) do
      packed = band(packed, 0xFFFF_FFFF_FFFF_FFFF)
      out_ptr = bsr(packed, 32)
      out_len = band(packed, 0xFFFF_FFFF)
      out = Wasmex.Memory.read_binary(store, memory, out_ptr, out_len)
      _ = Wasmex.call_function(pid, "fp_dealloc", [out_ptr, out_len], timeout)
      decode_raw(out)
    else
      other ->
        {:error,
         Refusal.new(:ferroplan_abi_failure, "#{op} raw call failed",
           details: %{result: inspect(other, limit: 5)}
         )}
    end
  rescue
    error ->
      {:error,
       Refusal.new(:ferroplan_abi_failure, "ferroplan raw call raised",
         details: %{error: Exception.message(error)}
       )}
  catch
    :exit, reason ->
      FerroplanTransport.stop(pid)

      {:error,
       Refusal.new(:ferroplan_call_timeout, "raw call exited or timed out; instance discarded",
         details: %{reason: inspect(reason), engine_restarted: true}
       )}
  end

  defp decode_raw(out) do
    case Jason.decode(out) do
      {:ok, %{"error" => err} = m} when map_size(m) == 1 ->
        err = if is_map(err), do: err, else: %{}

        {:error,
         Refusal.new(:ferroplan_engine_error, to_string(err["message"] || "engine error"),
           details: %{
             code: err["code"],
             message: err["message"],
             retryable: err["retryable"] == true
           }
         )}

      {:ok, %{} = m} ->
        {:ok, m}

      {:ok, other} ->
        {:ok, %{"value" => other}}

      _ ->
        {:error, Refusal.new(:ferroplan_bad_response, "response is not JSON")}
    end
  end
end
