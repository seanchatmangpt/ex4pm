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
    * a facade over the wasm ABI ops, each returning
      `{:ok, response_map} | {:error, %Ex4pm.Refusal{}}`:

      | function | wasm op | request fields |
      |---|---|---|
      | `plan/4` | `plan` | `domain`, `problem` (PDDL text) + extra |
      | `plan_production/4` | `plan_production` | `domain`, `problem` + extra |
      | `hierarchical_plan/3` | `htn_plan` | `problem` (PlanningProblem JSON), `limits` |
      | `fond_policy/3` | `fond_policy` | `problem` (PlanningProblem JSON), `limits` |
      | `hddl_solve/4` | `hddl_solve` | `domain`, `problem` (HDDL text), `limits` |
      | `fond_policy_validate/3` | `fond_policy_validate` | `problem`, `plan` |
      | `fond_validate/3` | `fond_validate` | `problem`, `plan` |
      | `explain/4` | `explain` | `domain`, `problem` (PDDL), `plan` (Plan map) |
      | `readiness/1`, `version/1` | `readiness`, `version` | none |

  ## Options

    * `:ferroplan_artifact` -- path to the wasm (default
      `priv/ferroplan/ferroplan_wasm.wasm` of the `:ex4pm` app)
    * `:ferroplan_expected_sha256` -- admitted digest (hex, optional `sha256:`
      prefix). Default: read from `MANIFEST.json` beside the artifact. With no
      pin the artifact is NOT admitted.
    * `:timeout` -- per-call timeout forwarded to the transport

  ## Refusal codes (`%Ex4pm.Refusal{code: code}`)

    * `:ferroplan_bad_input` -- arguments of the wrong shape (checked before
      any wasm call)
    * `:ferroplan_artifact_missing` -- artifact file absent
    * `:ferroplan_digest_unpinned` -- no admitted digest pin available
    * `:ferroplan_digest_mismatch` -- artifact digest differs from the pin
    * `:ferroplan_engine_error` -- the wasm returned an error envelope
      (execute/3 path; the facade returns the transport's own error)
    * `:ferroplan_unsupported_operation` -- `execute/3` given an operation
      this engine does not expose

  ## Engine operations (`execute/3`)

  `:ferroplan_plan`, `:ferroplan_plan_production`, `:ferroplan_readiness`,
  `:ferroplan_version`, `:ferroplan_hierarchical_plan`, `:ferroplan_fond_policy`,
  `:ferroplan_hddl_solve`, `:ferroplan_fond_policy_validate`,
  `:ferroplan_fond_validate`, `:ferroplan_explain`. The bare `:plan`
  operation is accepted (as `:ferroplan_plan`) when `engine: :ferroplan` is
  passed explicitly, so `Ex4pm.plan(problem, engine: :ferroplan)` routes here.
  The subject is a map with `:domain`, `:problem`, `:limits`, `:plan`, `:extra`
  keys as required by the operation (see the table above).
  """
  @behaviour Ex4pm.Engine

  alias Ex4pm.Engine.Ferroplan.Host
  alias Ex4pm.Engine.Result
  alias Ex4pm.Refusal

  @type opts :: keyword()
  @type response :: {:ok, map()} | {:error, Refusal.t() | term()}
  @type problem_json :: binary() | map()
  @type plan_arg :: binary() | map()

  @ops %{
    ferroplan_plan: "plan",
    ferroplan_plan_production: "plan_production",
    ferroplan_readiness: "readiness",
    ferroplan_version: "version",
    ferroplan_hierarchical_plan: "htn_plan",
    ferroplan_fond_policy: "fond_policy",
    ferroplan_hddl_solve: "hddl_solve",
    ferroplan_fond_policy_validate: "fond_policy_validate",
    ferroplan_fond_validate: "fond_validate",
    ferroplan_explain: "explain"
  }

  @impl true
  def id, do: :ferroplan

  @impl true
  def supports?(:plan, opts), do: Keyword.get(opts, :engine) == :ferroplan
  def supports?(operation, _opts), do: Map.has_key?(@ops, operation)

  @doc "True iff the artifact is present and its digest is admitted."
  @impl true
  @spec available?(opts()) :: boolean()
  def available?(opts), do: match?({:ok, _}, admit(opts))

  @doc "Whether the default (or configured) artifact file exists."
  @spec wasm_built?(opts()) :: boolean()
  def wasm_built?(opts \\ []), do: File.regular?(artifact_path(opts))

  @doc "Path of the wasm artifact: `:ferroplan_artifact` opt, app env, or the bundled `priv/` file."
  @spec artifact_path(opts()) :: Path.t()
  def artifact_path(opts \\ []) do
    Keyword.get_lazy(opts, :ferroplan_artifact, fn ->
      Application.get_env(:ex4pm, :ferroplan_artifact) ||
        Application.app_dir(:ex4pm, "priv/ferroplan/ferroplan_wasm.wasm")
    end)
  end

  # --- facade ---------------------------------------------------------

  @doc """
  Classical PDDL planning (`plan` op). `extra` is merged into the request
  (`"mode"`, `"search"`, `"flags"`). Returns the solution map
  (`"solved"`, `"plan"`, `"statistics"`, ...). Refuses `:ferroplan_bad_input`
  unless `domain`/`problem` are binaries and `extra` is a map.
  """
  @spec plan(binary(), binary(), map(), opts()) :: response()
  def plan(domain, problem, extra \\ %{}, opts \\ [])

  def plan(domain, problem, extra, opts)
      when is_binary(domain) and is_binary(problem) and is_map(extra) do
    run("plan", Map.merge(extra, %{"domain" => domain, "problem" => problem}), opts)
  end

  def plan(d, p, e, _), do: bad_input(:plan, {d, p, e})

  @doc """
  Production planning (`plan_production` op): an operation envelope whose
  authority is `candidate_only`. Same arguments and refusals as `plan/4`;
  `extra` may carry `"max_evaluated"`, `"max_plan_steps"`, `"max_output_bytes"`,
  `"request_id"`.
  """
  @spec plan_production(binary(), binary(), map(), opts()) :: response()
  def plan_production(domain, problem, extra \\ %{}, opts \\ [])

  def plan_production(domain, problem, extra, opts)
      when is_binary(domain) and is_binary(problem) and is_map(extra) do
    run("plan_production", Map.merge(extra, %{"domain" => domain, "problem" => problem}), opts)
  end

  def plan_production(d, p, e, _), do: bad_input(:plan_production, {d, p, e})

  @doc "Capability manifest + fingerprint (`readiness` op)."
  @spec readiness(opts()) :: response()
  def readiness(opts \\ []), do: run("readiness", %{}, opts)

  @doc "Wasm build version (`version` op): `{:ok, %{\"version\" => vsn}}`."
  @spec version(opts()) :: response()
  def version(opts \\ []), do: run("version", %{}, opts)

  @doc """
  HTN planning (`htn_plan` op). `problem` is a PlanningProblem as JSON text
  or a map (JSON-encoded here); there is no `domain` field. `limits` is an
  optional partial PlannerLimits map. Returns a UniversalPlan map
  (`"solved"`, `"planning_type"`, `"policy"`, ...). A malformed problem is a
  transport error; `:ferroplan_bad_input` for wrong argument types.
  """
  @spec hierarchical_plan(problem_json(), map() | nil, opts()) :: response()
  def hierarchical_plan(problem, limits \\ nil, opts \\ []),
    do: universal("htn_plan", problem, limits, opts)

  @doc """
  FOND policy synthesis (`fond_policy` op). Same request shape and refusals
  as `hierarchical_plan/3`; the response additionally carries `"validation"`
  (a policy validation report with `"guarantee"`).
  """
  @spec fond_policy(problem_json(), map() | nil, opts()) :: response()
  def fond_policy(problem, limits \\ nil, opts \\ []),
    do: universal("fond_policy", problem, limits, opts)

  @doc """
  HDDL solving (`hddl_solve` op): HDDL `domain`/`problem` text plus optional
  partial `limits`. Returns a UniversalPlan map. A malformed HDDL document
  yields the transport's engine error (codes such as `FP_PARSE`).
  """
  @spec hddl_solve(binary(), binary(), map() | nil, opts()) :: response()
  def hddl_solve(domain, problem, limits \\ nil, opts \\ [])

  def hddl_solve(domain, problem, limits, opts)
      when is_binary(domain) and is_binary(problem) and (is_map(limits) or is_nil(limits)) do
    req = %{"domain" => domain, "problem" => problem}
    run("hddl_solve", put_limits(req, limits), opts)
  end

  def hddl_solve(d, p, l, _), do: bad_input(:hddl_solve, {d, p, l})

  @doc """
  Independently validates a FOND policy (`fond_policy_validate` op).
  `problem` is PlanningProblem JSON text or map; `plan` is a UniversalPlan
  map or its JSON text. Returns a report map (`"valid"`, `"guarantee"`,
  `"reachable_states"`, `"issues"`). Evidence only; never executes anything.
  """
  @spec fond_policy_validate(problem_json(), plan_arg(), opts()) :: response()
  def fond_policy_validate(problem, plan, opts \\ []),
    do: validate("fond_policy_validate", problem, plan, opts)

  @doc """
  Like `fond_policy_validate/3` but with structured `FP_*` refusals for an
  undecodable problem/plan (returned as the response's `"error"` envelope).
  """
  @spec fond_validate(problem_json(), plan_arg(), opts()) :: response()
  def fond_validate(problem, plan, opts \\ []),
    do: validate("fond_validate", problem, plan, opts)

  @doc """
  Explains a classical plan (`explain` op): `domain`/`problem` PDDL text and
  `plan` as a Plan map (`%{"steps" => [...], "length" => n}`, as returned in
  `plan/4`'s `"plan"` field) or its JSON text. Returns `"kind"`,
  `"causal_links"`, `"invariant_spans"`, `"preferences"`.
  """
  @spec explain(binary(), binary(), plan_arg(), opts()) :: response()
  def explain(domain, problem, plan, opts \\ [])

  def explain(domain, problem, plan, opts)
      when is_binary(domain) and is_binary(problem) and (is_map(plan) or is_binary(plan)) do
    with {:ok, plan_map} <- decode_object(plan, :explain) do
      run("explain", %{"domain" => domain, "problem" => problem, "plan" => plan_map}, opts)
    end
  end

  def explain(d, p, pl, _), do: bad_input(:explain, {d, p, pl})

  defp universal(op, problem, limits, opts)
       when (is_binary(problem) or is_map(problem)) and (is_map(limits) or is_nil(limits)) do
    run(op, put_limits(%{"problem" => encode_json_text(problem)}, limits), opts)
  end

  defp universal(op, p, l, _), do: bad_input(op, {p, l})

  defp validate(op, problem, plan, opts)
       when (is_binary(problem) or is_map(problem)) and (is_binary(plan) or is_map(plan)) do
    # fond_validate requires a plan object; fond_policy_validate accepts both,
    # so always send the decoded object.
    with {:ok, plan_map} <- decode_object(plan, op) do
      run(op, %{"problem" => encode_json_text(problem), "plan" => plan_map}, opts)
    end
  end

  defp validate(op, p, pl, _), do: bad_input(op, {p, pl})

  defp put_limits(req, nil), do: req
  defp put_limits(req, limits), do: Map.put(req, "limits", limits)

  defp encode_json_text(text) when is_binary(text), do: text
  defp encode_json_text(map) when is_map(map), do: Jason.encode!(map)

  defp decode_object(map, _op) when is_map(map), do: {:ok, map}

  defp decode_object(text, op) when is_binary(text) do
    case Jason.decode(text) do
      {:ok, %{} = m} -> {:ok, m}
      _ -> bad_input(op, {:plan, text})
    end
  end

  defp bad_input(op, subject) do
    {:error,
     Refusal.new(:ferroplan_bad_input, "ferroplan #{op} received arguments of the wrong shape",
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

  defp fetch_op(:plan), do: {:ok, "plan"}

  defp fetch_op(operation) do
    case Map.fetch(@ops, operation) do
      {:ok, op} ->
        {:ok, op}

      :error ->
        {:error,
         Refusal.new(
           :ferroplan_unsupported_operation,
           "ferroplan does not support this operation",
           details: %{operation: operation}
         )}
    end
  end

  defp request_for(op, _subject) when op in ["readiness", "version"], do: {:ok, %{}}

  defp request_for(op, subject) when is_map(subject) do
    build_request(op, subject)
  end

  defp request_for(op, _),
    do:
      {:error,
       Refusal.new(:ferroplan_bad_input, "subject must be a map for #{op}",
         details: %{operation: op}
       )}

  # PDDL-text ops: domain + problem binaries, optional :limits and :extra.
  defp build_request(op, subject) when op in ["plan", "plan_production"] do
    domain = fetch_key(subject, :domain)
    problem = fetch_key(subject, :problem)

    if is_binary(domain) and is_binary(problem) do
      base =
        put_limits(
          %{"domain" => domain, "problem" => problem},
          map_or_nil(fetch_key(subject, :limits))
        )

      extra = fetch_key(subject, :extra)
      {:ok, if(is_map(extra), do: Map.merge(extra, base), else: base)}
    else
      subject_refusal(op, "subject must carry binary :domain and :problem")
    end
  end

  defp build_request("hddl_solve", subject) do
    domain = fetch_key(subject, :domain)
    problem = fetch_key(subject, :problem)

    if is_binary(domain) and is_binary(problem) do
      {:ok,
       put_limits(
         %{"domain" => domain, "problem" => problem},
         map_or_nil(fetch_key(subject, :limits))
       )}
    else
      subject_refusal("hddl_solve", "subject must carry binary :domain and :problem")
    end
  end

  # PlanningProblem-JSON ops: no domain field.
  defp build_request(op, subject) when op in ["htn_plan", "fond_policy"] do
    case fetch_key(subject, :problem) do
      p when is_binary(p) or is_map(p) ->
        {:ok,
         put_limits(%{"problem" => encode_json_text(p)}, map_or_nil(fetch_key(subject, :limits)))}

      _ ->
        subject_refusal(op, "subject must carry :problem (PlanningProblem JSON text or map)")
    end
  end

  defp build_request(op, subject) when op in ["fond_policy_validate", "fond_validate"] do
    problem = fetch_key(subject, :problem)

    with true <- is_binary(problem) or is_map(problem),
         {:ok, plan} <- plan_object(fetch_key(subject, :plan)) do
      {:ok, %{"problem" => encode_json_text(problem), "plan" => plan}}
    else
      _ -> subject_refusal(op, "subject must carry :problem and :plan (map or JSON text)")
    end
  end

  defp build_request("explain", subject) do
    domain = fetch_key(subject, :domain)
    problem = fetch_key(subject, :problem)

    with true <- is_binary(domain) and is_binary(problem),
         {:ok, plan} <- plan_object(fetch_key(subject, :plan)) do
      {:ok, %{"domain" => domain, "problem" => problem, "plan" => plan}}
    else
      _ ->
        subject_refusal("explain", "subject must carry binary :domain, :problem and a :plan map")
    end
  end

  defp plan_object(m) when is_map(m), do: {:ok, m}

  defp plan_object(t) when is_binary(t) do
    case Jason.decode(t) do
      {:ok, %{} = m} -> {:ok, m}
      _ -> :error
    end
  end

  defp plan_object(_), do: :error

  defp map_or_nil(m) when is_map(m), do: m
  defp map_or_nil(_), do: nil

  defp subject_refusal(op, msg),
    do: {:error, Refusal.new(:ferroplan_bad_input, msg, details: %{operation: op})}

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

    result =
      Ex4pm.Engine.CallLog.wrap(
        :ferroplan,
        op,
        admission.sha256,
        Keyword.put(opts, :call_log_artifact, "sha256:" <> admission.sha256),
        fn -> do_run_admitted(op, request, admission, opts) end
      )

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
         Refusal.new(
           :ferroplan_digest_unpinned,
           "no admitted digest pin for the ferroplan artifact",
           details: %{hint: "MANIFEST.json beside the artifact or :ferroplan_expected_sha256"}
         )}
    end
  end
end
