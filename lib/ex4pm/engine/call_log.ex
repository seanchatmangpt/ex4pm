defmodule Ex4pm.Engine.CallLog do
  @moduledoc """
  Single call chokepoint that lets ex4pm observe its own engine usage.

  `wrap/4,5` runs an engine call, measures it, and (never altering or raising
  into the wrapped result) emits:

    * `:telemetry` `[:ex4pm, :engine, :call, :stop]` with measurements
      `%{duration: native_time}` and metadata
      `%{engine, operation, standing, refusal_code, replay_verified, duration_ms}`;
    * one OCEL 2.0 batch envelope (valid for `Ex4pm.OCEL.validate_envelope/1`)
      with activity `"engine.<engine_id>.<operation>"`, objects
      engine / artifact / run, and attributes standing, duration_ms,
      replay_verified, refusal;
    * a local fan-out to `subscribe/0` subscribers and an ETS ring buffer
      (`events/0`), both owned by a lazily started process (no entry in
      `application.ex`);
    * optionally `Ex4pm.Engine.OnlineMiner.ingest/2` when `opts[:call_log_ingest]`
      is a pid or registered name.

  Disabled by `opts[:call_log] == false` or `config :ex4pm, :call_log, false`
  (default enabled). Observation failures are swallowed into a typed note in
  `last_note/0`; the wrapped result is returned bit-identically.
  """

  use GenServer

  @registry Ex4pm.Engine.CallLog.Registry
  @table :ex4pm_engine_call_log
  @cap 1000
  @schema "ocel2.0/engine-call-log.v1"

  # ---- public API -----------------------------------------------------

  @doc "True unless disabled through `opts[:call_log]` or application config."
  def enabled?(opts \\ []) do
    Keyword.get(opts, :call_log, true) != false and
      Application.get_env(:ex4pm, :call_log, true) != false
  end

  @doc """
  Runs `fun` and logs the call. `subject_digest` is a binary or a 0-arity
  function producing one (evaluated only when logging is enabled).
  """
  def wrap(engine_id, operation, subject_digest, fun) when is_function(fun, 0),
    do: wrap(engine_id, operation, subject_digest, [], fun)

  def wrap(engine_id, operation, subject_digest, opts, fun) when is_function(fun, 0) do
    if enabled?(opts) do
      t0 = System.monotonic_time()
      started_at = DateTime.utc_now()
      result = fun.()
      duration = System.monotonic_time() - t0
      observe(engine_id, operation, subject_digest, opts, result, duration, started_at)
      result
    else
      fun.()
    end
  end

  @doc "Subscribes the caller to `{:ex4pm_engine_call, envelope}` messages."
  def subscribe do
    :ok = ensure_started()
    {:ok, _} = Registry.register(@registry, :calls, nil)
    :ok
  end

  def unsubscribe do
    case Process.whereis(@registry) do
      nil -> :ok
      _ -> Registry.unregister(@registry, :calls)
    end
  end

  @doc "Buffered OCEL envelopes, oldest first (ring buffer, last #{@cap})."
  def events do
    case :ets.whereis(@table) do
      :undefined -> []
      _ -> @table |> :ets.tab2list() |> Enum.sort() |> Enum.map(&elem(&1, 1))
    end
  rescue
    ArgumentError -> []
  end

  def clear do
    case :ets.whereis(@table) do
      :undefined -> :ok
      _ -> :ets.delete_all_objects(@table) && :ok
    end
  rescue
    ArgumentError -> :ok
  end

  @doc "Most recent typed observation-failure note, or nil."
  def last_note do
    case :ets.whereis(@table) do
      :undefined -> nil
      _ -> with [{:note, n}] <- :ets.lookup(@table, :note), do: n, else: (_ -> nil)
    end
  rescue
    ArgumentError -> nil
  end

  # ---- observation ----------------------------------------------------

  defp observe(engine_id, operation, subject_digest, opts, result, duration, started_at) do
    :ok = ensure_started()
    info = classify(result)
    info = %{info | artifact: info.artifact || opts[:call_log_artifact]}
    duration_ms = System.convert_time_unit(duration, :native, :microsecond) / 1000

    meta = %{
      engine: engine_id,
      operation: operation,
      standing: info.standing,
      refusal_code: info.refusal_code,
      replay_verified: info.replay_verified,
      duration_ms: duration_ms
    }

    :telemetry.execute([:ex4pm, :engine, :call, :stop], %{duration: duration}, meta)

    envelope =
      build_envelope(engine_id, operation, digest(subject_digest), info, duration_ms, started_at)

    store(envelope)

    Registry.dispatch(@registry, :calls, fn es ->
      for {pid, _} <- es, do: send(pid, {:ex4pm_engine_call, envelope})
    end)

    maybe_ingest(opts, envelope)
    :ok
  rescue
    e -> note({:call_log_observation_failed, Exception.message(e)})
  catch
    kind, reason -> note({:call_log_observation_failed, {kind, inspect(reason)}})
  end

  defp classify({:ok, %{standing: standing} = r}) do
    ev = Map.get(r, :evidence) || %{}

    sha =
      Map.get(ev, :wasm_sha256) ||
        case Map.get(ev, :transport_identity) do
          %{} = id -> Map.get(id, :wasm_sha256) || Map.get(id, "wasm_sha256")
          _ -> nil
        end

    %{
      standing: standing,
      refusal_code: nil,
      replay_verified: Map.get(ev, :replay_verified) == true,
      artifact: sha
    }
  end

  defp classify({:ok, _}), do: base(:ok, nil)
  defp classify({:error, %{code: code}}), do: base(:refused, code)
  defp classify({:error, other}), do: base(:refused, other |> inspect() |> String.slice(0, 80))
  defp classify(_), do: base(:unknown, nil)

  defp base(standing, code),
    do: %{standing: standing, refusal_code: code, replay_verified: false, artifact: nil}

  defp digest(fun) when is_function(fun, 0), do: digest(fun.())
  defp digest(bin) when is_binary(bin), do: bin
  defp digest(nil), do: "unknown"
  defp digest(other), do: inspect(other)

  defp build_envelope(engine_id, operation, subject_digest, info, duration_ms, started_at) do
    n = System.unique_integer([:positive, :monotonic])
    run_id = "run:#{n}"
    engine_oid = "engine:#{engine_id}"
    artifact_oid = "artifact:#{info.artifact || "unobserved"}"
    ts = DateTime.to_iso8601(started_at)

    %{
      "schema" => @schema,
      "producer" => %{"agent_id" => "ex4pm.engine.call_log", "run_id" => run_id},
      "sequence" => n,
      "events" => [
        %{
          "id" => "call:#{n}",
          "activity" => "engine.#{engine_id}.#{operation}",
          "timestamp" => ts,
          "relationships" => [
            %{"objectId" => engine_oid, "qualifier" => "engine"},
            %{"objectId" => artifact_oid, "qualifier" => "artifact"},
            %{"objectId" => run_id, "qualifier" => "run"}
          ],
          "attributes" => %{
            "standing" => to_string(info.standing),
            "duration_ms" => duration_ms,
            "replay_verified" => info.replay_verified,
            "refusal" => info.refusal_code && to_string(info.refusal_code),
            "subject_digest" => subject_digest
          }
        }
      ],
      "objects" => %{
        engine_oid => %{"type" => "engine", "id" => engine_oid},
        artifact_oid => %{"type" => "artifact", "id" => artifact_oid},
        run_id => %{"type" => "run", "id" => run_id}
      }
    }
  end

  defp store(envelope) do
    key = envelope["sequence"]
    :ets.insert(@table, {key, envelope})
    if :ets.info(@table, :size) > @cap + 1, do: GenServer.cast(__MODULE__, :trim)
  end

  defp maybe_ingest(opts, envelope) do
    case Keyword.get(opts, :call_log_ingest) do
      nil ->
        :ok

      server ->
        [event] = envelope["events"]

        miner_event = %{
          id: event["id"],
          activity: event["activity"],
          timestamp: event["timestamp"],
          objects: Enum.map(event["relationships"], & &1["objectId"]),
          attributes: event["attributes"]
        }

        try do
          Ex4pm.Engine.OnlineMiner.ingest(miner_event, server)
        catch
          :exit, reason -> note({:call_log_ingest_failed, inspect(reason)})
        end
    end

    :ok
  end

  defp note(n) do
    :ets.insert(@table, {:note, n})
    :ok
  rescue
    _ -> :ok
  end

  # ---- lazily started owner ------------------------------------------

  defp ensure_started do
    case Process.whereis(__MODULE__) do
      nil ->
        case GenServer.start(__MODULE__, :ok, name: __MODULE__) do
          {:ok, _} -> :ok
          {:error, {:already_started, _}} -> :ok
          other -> raise "call_log owner failed: #{inspect(other)}"
        end

      _ ->
        :ok
    end
  end

  @impl true
  def init(:ok) do
    :ets.new(@table, [:named_table, :ordered_set, :public, read_concurrency: true])
    {:ok, _} = Registry.start_link(keys: :duplicate, name: @registry)
    {:ok, %{}}
  end

  @impl true
  def handle_cast(:trim, state) do
    trim()
    {:noreply, state}
  end

  defp trim do
    keys = for {k, _} when is_integer(k) <- :ets.tab2list(@table), do: k
    excess = length(keys) - @cap

    if excess > 0,
      do: keys |> Enum.sort() |> Enum.take(excess) |> Enum.each(&:ets.delete(@table, &1))
  end
end
