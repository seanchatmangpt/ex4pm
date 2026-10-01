defmodule Ex4pm.Engine.Ferroplan.Host do
  @moduledoc false
  # One lazily started, unlinked-from-callers GenServer per node. It owns the
  # wasm transport instances (one per artifact path + digest) so repeated
  # calls reuse the instance and a short-lived caller cannot kill it.
  use GenServer

  @name __MODULE__

  def fetch(artifact, opts) do
    ensure_started()
    GenServer.call(@name, {:fetch, artifact, opts}, 60_000)
  end

  def stop_all do
    if Process.whereis(@name), do: GenServer.call(@name, :stop_all, 30_000), else: :ok
  end

  defp ensure_started do
    case GenServer.start(__MODULE__, %{}, name: @name) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:fetch, artifact, opts}, _from, state) do
    key = {artifact, Keyword.get(opts, :wasm_sha256)}

    case Map.get(state, key) do
      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          {:reply, {:ok, pid}, state}
        else
          start(key, artifact, opts, Map.delete(state, key))
        end

      nil ->
        start(key, artifact, opts, state)
    end
  end

  def handle_call(:stop_all, _from, state) do
    for {_k, pid} <- state, Process.alive?(pid) do
      try do
        Ex4pmEngine.Wasm.FerroplanTransport.stop(pid)
      catch
        _, _ -> :ok
      end
    end

    {:reply, :ok, %{}}
  end

  defp start(key, artifact, opts, state) do
    case Ex4pmEngine.Wasm.FerroplanTransport.start(artifact, Keyword.delete(opts, :wasm_sha256)) do
      {:ok, pid} -> {:reply, {:ok, pid}, Map.put(state, key, pid)}
      {:error, _} = err -> {:reply, err, state}
    end
  end
end

defmodule Ex4pm.Engine.Ferroplan do
  @moduledoc """
  ferroplan PDDL/HTN/FOND planning engine, executed as an admitted
  `wasm32-wasip1` artifact through `Ex4pmEngine.Wasm.FerroplanTransport`.

  Two surfaces:

    * the `Ex4pm.Engine` behaviour (`id/0`, `supports?/2`, `available?/1`,
      `execute/3`) -- results carry evidence (`executed: true`,
      `wasm_sha256`, `source_version`) and are `:alive` only when the
      artifact digest was admitted AND the call really executed;
    * a facade mirroring `BeamPM.Ferroplan`: `plan/4`, `plan_production/4`,
      `readiness/1`, `version/1`, `hierarchical_plan/4`, `fond_policy/4`,
      `hddl_solve/4`, `wasm_built?/0`, each returning `{:ok, map} | {:error, term}`.

  ## Options

    * `:ferroplan_artifact` -- path to the wasm (default
      `priv/ferroplan/ferroplan_wasm.wasm` of the `:ex4pm` app)
    * `:ferroplan_expected_sha256` -- admitted digest (hex, optional `sha256:`
      prefix). Default: read from `MANIFEST.json` beside the artifact. With no
      pin the artifact is NOT admitted.
    * `:timeout` -- per-call timeout forwarded to the transport
  """
  @behaviour Ex4pm.Engine

  alias Ex4pm.Engine.Ferroplan.Host
  alias Ex4pm.Engine.Result
  alias Ex4pm.Refusal

  @ops %{
    ferroplan_plan: "plan",
    ferroplan_plan_production: "plan_production",
    ferroplan_readiness: "readiness",
    ferroplan_version: "version",
    ferroplan_hierarchical_plan: "htn_plan",
    ferroplan_fond_policy: "fond_policy"
  }

  @impl true
  def id, do: :ferroplan

  @impl true
  def supports?(operation, _opts), do: Map.has_key?(@ops, operation)

  @doc "True iff the artifact is present and its digest is admitted."
  @impl true
  def available?(opts), do: match?({:ok, _}, admit(opts))

  @doc "Whether the default (or configured) artifact file exists."
  def wasm_built?(opts \\ []), do: File.regular?(artifact_path(opts))

  def artifact_path(opts \\ []) do
    Keyword.get_lazy(opts, :ferroplan_artifact, fn ->
      Application.get_env(:ex4pm, :ferroplan_artifact) ||
        Application.app_dir(:ex4pm, "priv/ferroplan/ferroplan_wasm.wasm")
    end)
  end

  # --- facade ---------------------------------------------------------

  def plan(domain, problem, extra \\ %{}, opts \\ [])

  def plan(domain, problem, extra, opts)
      when is_binary(domain) and is_binary(problem) and is_map(extra) do
    run("plan", Map.merge(extra, %{"domain" => domain, "problem" => problem}), opts)
  end

  def plan(d, p, e, _), do: bad_input(:plan, {d, p, e})

  def plan_production(domain, problem, extra \\ %{}, opts \\ [])

  def plan_production(domain, problem, extra, opts)
      when is_binary(domain) and is_binary(problem) and is_map(extra) do
    run("plan_production", Map.merge(extra, %{"domain" => domain, "problem" => problem}), opts)
  end

  def plan_production(d, p, e, _), do: bad_input(:plan_production, {d, p, e})

  def readiness(opts \\ []), do: run("readiness", %{}, opts)
  def version(opts \\ []), do: run("version", %{}, opts)

  def hierarchical_plan(domain, problem, limits \\ nil, opts \\ []),
    do: structured("htn_plan", domain, problem, limits, opts)

  def fond_policy(domain, problem, limits \\ nil, opts \\ []),
    do: structured("fond_policy", domain, problem, limits, opts)

  def hddl_solve(domain, problem, limits \\ nil, opts \\ []),
    do: structured("hddl_solve", domain, problem, limits, opts)

  defp structured(op, domain, problem, limits, opts)
       when is_binary(domain) and is_binary(problem) and (is_map(limits) or is_nil(limits)) do
    req = %{"domain" => domain, "problem" => problem}
    run(op, if(limits, do: Map.put(req, "limits", limits), else: req), opts)
  end

  defp structured(op, d, p, l, _), do: bad_input(op, {d, p, l})

  defp bad_input(op, subject) do
    {:error,
     Refusal.new(:ferroplan_bad_input, "ferroplan #{op} requires binary domain/problem and map extra/limits",
       details: %{operation: op, subject: inspect(subject)}
     )}
  end

  # --- behaviour execute ----------------------------------------------

  @impl true
  def execute(operation, subject, opts) do
    with {:ok, op} <- fetch_op(operation),
         {:ok, request} <- request_for(op, subject),
         {:ok, admission} <- admit(opts),
         {:ok, response} <- run_admitted(op, request, admission, opts),
         :ok <- check_envelope(operation, response) do
      {:ok,
       %Result{
         engine: :ferroplan,
         operation: operation,
         algorithm: String.to_atom(op),
         subject_hash: Ex4pm.Core.Hash.digest(subject),
         standing: standing_for(op),
         value: response,
         evidence: %{
           executed: true,
           candidate_only: op == "plan_production",
           admitted: true,
           wasm_sha256: admission.sha256,
           artifact: admission.path,
           source_version: admission.source_version || source_version(admission, opts)
         }
       }}
    end
  end

  # plan_production is always candidate-only: never claim :alive from it.
  defp standing_for("plan_production"), do: :partial_alive
  defp standing_for(_), do: :alive

  defp fetch_op(:ferroplan_fond_policy_validate) do
    {:error,
     Refusal.new(:ferroplan_unsupported_operation, "fond_policy_validate is not exposed by the ferroplan wasm ABI",
       details: %{operation: :ferroplan_fond_policy_validate}
     )}
  end

  defp fetch_op(operation) do
    case Map.fetch(@ops, operation) do
      {:ok, op} ->
        {:ok, op}

      :error ->
        {:error,
         Refusal.new(:ferroplan_unsupported_operation, "ferroplan does not support this operation",
           details: %{operation: operation}
         )}
    end
  end

  defp request_for(op, _subject) when op in ["readiness", "version"], do: {:ok, %{}}

  defp request_for(op, subject) when is_map(subject) do
    domain = fetch_key(subject, :domain)
    problem = fetch_key(subject, :problem)

    if is_binary(domain) and is_binary(problem) do
      base = %{"domain" => domain, "problem" => problem}

      base =
        case fetch_key(subject, :limits) do
          l when is_map(l) -> Map.put(base, "limits", l)
          _ -> base
        end

      extra = fetch_key(subject, :extra)
      {:ok, if(is_map(extra), do: Map.merge(extra, base), else: base)}
    else
      {:error,
       Refusal.new(:ferroplan_bad_input, "subject must carry binary :domain and :problem",
         details: %{operation: op}
       )}
    end
  end

  defp request_for(op, _),
    do:
      {:error,
       Refusal.new(:ferroplan_bad_input, "subject must be a map with :domain and :problem",
         details: %{operation: op}
       )}

  defp fetch_key(map, key), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))

  defp check_envelope(operation, %{"error" => err}) when not is_nil(err) do
    {:error,
     Refusal.new(:ferroplan_engine_error, "ferroplan returned an error envelope",
       details: %{operation: operation, error: err}
     )}
  end

  defp check_envelope(_, _), do: :ok

  # Facade path: admission is enforced identically (no un-admitted execution).
  defp run(op, request, opts) do
    with {:ok, admission} <- admit(opts) do
      run_admitted(op, request, admission, opts)
    end
  end

  defp run_admitted(op, request, admission, opts) do
    t0 = System.monotonic_time()
    result = do_run_admitted(op, request, admission, opts)

    :telemetry.execute(
      [:ex4pm, :engine, :ferroplan, String.to_atom(op)],
      %{duration: System.monotonic_time() - t0},
      %{ok: match?({:ok, _}, result)}
    )

    result
  end

  defp do_run_admitted(op, request, admission, opts) do
    topts = [wasm_sha256: admission.sha256, expected_sha256: admission.sha256]

    with {:ok, pid} <- Host.fetch(admission.path, topts) do
      Ex4pmEngine.Wasm.FerroplanTransport.call(pid, op, request, Keyword.take(opts, [:timeout]))
    end
  end

  defp source_version(admission, opts) do
    case run_admitted("version", %{}, admission, opts) do
      {:ok, %{} = v} -> v["version"] || v["ferroplan"] || v
      _ -> nil
    end
  end

  # --- admission ------------------------------------------------------

  defp admit(opts) do
    path = artifact_path(opts)

    with {:ok, bytes} <- read_artifact(path),
         actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower),
         manifest = read_manifest(path),
         {:ok, expected} <- expected_digest(opts, manifest, actual) do
      if expected == :unpinned or expected == actual do
        {:ok,
         %{
           path: path,
           sha256: actual,
           source_version: manifest["source_version"] || manifest["version"]
         }}
      else
        {:error,
         Refusal.new(:ferroplan_digest_mismatch, "artifact digest differs from the admitted pin",
           details: %{expected: expected, actual: actual, path: path}
         )}
      end
    end
  end

  defp read_artifact(path) do
    case File.read(path) do
      {:ok, bytes} ->
        {:ok, bytes}

      {:error, reason} ->
        {:error,
         Refusal.new(:ferroplan_artifact_missing, "ferroplan wasm artifact is not present",
           details: %{path: path, reason: reason}
         )}
    end
  end

  defp read_manifest(path) do
    with {:ok, text} <- File.read(Path.join(Path.dirname(path), "MANIFEST.json")),
         {:ok, %{} = m} <- Jason.decode(text) do
      m
    else
      _ -> %{}
    end
  end

  defp expected_digest(opts, manifest, _actual) do
    pin =
      Keyword.get(opts, :ferroplan_expected_sha256) ||
        Enum.find_value(["wasm_sha256", "sha256", "artifact_sha256"], &manifest[&1]) ||
        get_in(manifest, ["artifact", "sha256"])

    case pin do
      :unpinned ->
        # Explicit opt-in only; never reached by default.
        {:ok, :unpinned}

      "sha256:" <> hex ->
        {:ok, String.downcase(hex)}

      hex when is_binary(hex) ->
        {:ok, String.downcase(hex)}

      _ ->
        {:error,
         Refusal.new(:ferroplan_digest_unpinned, "no admitted digest pin for the ferroplan artifact",
           details: %{hint: "MANIFEST.json beside the artifact or :ferroplan_expected_sha256"}
         )}
    end
  end
end
