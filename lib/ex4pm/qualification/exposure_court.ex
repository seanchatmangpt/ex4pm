# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pm.Qualification.ExposureCourt do
  @moduledoc """
  Exposure-completeness court: every capability the bundled artifacts can
  execute must be exposed, documented and really tested -- or explicitly
  declared unsupported with a reason.

  Subjects are enumerated from sources of truth, not from the code under test:

    * the algorithm ids of `Ex4pmEngine.Wasm.AlgoRegistry`;
    * the export section of `priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm`, parsed
      here and compared to the registry's export names (`EXPORT_DRIFT`);
    * the `ops` of `priv/ferroplan/MANIFEST.json`.

  Typed violations (`broken_term`): `REFUSED_EXPOSURE_NO_ADAPTER`,
  `..._NO_ENGINE_OP`, `..._NO_PUBLIC_FUNCTION`, `..._NO_DOC`,
  `..._NO_REAL_TEST`, `..._EXPORT_DRIFT`, `..._SKIPPED_REAL_EXEC`,
  `..._STALE_KNOWN_GAP`, and, in `--require-real` mode, `..._NOT_ALIVE` / `..._ARTIFACT_MISSING`.

  The check functions (`violations/1`, `real_violations/2`) are pure over an
  inputs map, so the sabotage test can remove a subject and watch the court
  refuse. `run/1` additionally subtracts `known_gaps/0`: gaps that other work
  will close, each with an owner/phase. A violation outside that list is a new
  gap and refuses; list entries that no longer match any violation are
  themselves refused as stale (the list may only shrink).

  Session ops (`session_*`) are exposed through
  `Ex4pm.Engine.Ferroplan.Sessions`, not one function per op: the declared
  mapping is adapter/engine op = `Ex4pm.Engine.Ferroplan.Session.ops/0`
  contains the op (the GenServer that owns the wasm instance), public function
  = `Sessions.call/4` (plus the named lifecycle function for new/fork/free),
  real test = a ferroplan-marked test file that drives the op through the
  `Sessions` API (`Sessions.call(id, :op, ...)` or a facade function).
  """

  alias Ex4pm.Qualification.ExposureCourt.CanonicalRequests
  alias Ex4pmEngine.Wasm.{AlgoRegistry, RealTransport}

  @type subject ::
          {:algorithm, atom()}
          | {:wasm_export, String.t()}
          | {:ferroplan_op, String.t()}
          | {:test_file, String.t()}
          | {:known_gap, String.t()}
  @type violation :: %{
          broken_term: String.t(),
          layer: atom(),
          subject: subject(),
          detail: String.t()
        }

  @core_exports ~w(wasm4pm_ex4pm_bindings_alloc_v1 wasm4pm_ex4pm_bindings_dealloc_v1
                   wasm4pm_ex4pm_bindings_free_v1 wasm4pm_ex4pm_bindings_version_v1 memory)

  @ferroplan_modules [
    Ex4pm.Engine.Ferroplan,
    Ex4pm.Engine.Ferroplan.Session,
    Ex4pm.Ferroplan,
    Ex4pm.Ferroplan.Session
  ]

  @ferroplan_marker ~r/FerroplanTransport|Engine\.Ferroplan|real_ferroplan|ferroplan_wasm\.wasm/
  @session_module Ex4pm.Engine.Ferroplan.Session
  @sessions_module Ex4pm.Engine.Ferroplan.Sessions

  @function_aliases %{"htn_plan" => ["hierarchical_plan"], "hddl_solve" => ["hddl_solve"]}

  # -- known gaps ------------------------------------------------------------
  #
  # {layer, matcher, owner/phase}. matcher: {:algorithm, id} | {:ferroplan_op, op}
  # | {:ferroplan_op_prefix, prefix} | {:all_algorithms} | {:test_file_suffix, s}.
  # Every entry is a TODO owned by another lane/phase. The list is itself
  # checked: the cap test only lets it shrink, and an entry that no longer
  # matches any violation is a STALE refusal (`REFUSED_EXPOSURE_STALE_KNOWN_GAP`),
  # so the list can never hide a regression. Do not add entries to make the
  # court green.
  @known_gaps []

  @doc "Declared gaps `{layer, matcher, owner}` that `run/1` tolerates (and prints)."
  @spec known_gaps() :: [{atom(), tuple(), String.t()}]
  def known_gaps, do: @known_gaps

  # -- inputs ----------------------------------------------------------------

  @doc "Collects subjects and source texts from the real tree (`root` = project root)."
  @spec load_inputs(keyword()) :: map()
  def load_inputs(opts \\ []) do
    root = Keyword.get(opts, :root, File.cwd!())
    priv = Keyword.get_lazy(opts, :priv_dir, fn -> priv_dir(root) end)
    artifact = Path.join([priv, "wasm4pm", "wasm4pm_ex4pm_bindings.wasm"])
    manifest = Path.join([priv, "ferroplan", "MANIFEST.json"])

    %{
      root: root,
      priv_dir: priv,
      algorithms: AlgoRegistry.algo_specs(),
      engines: Ex4pm.Engine.Registry.engines(),
      artifact_exports:
        case File.read(artifact) do
          {:ok, bytes} -> {:ok, wasm_exports(bytes)}
          {:error, reason} -> {:error, reason}
        end,
      ferroplan_ops: manifest |> File.read!() |> Jason.decode!() |> Map.fetch!("ops"),
      ferroplan_sources: read_all(ferroplan_source_paths(root)),
      ferroplan_modules: @ferroplan_modules,
      tests: read_all(Path.wildcard(Path.join(root, "test/**/*_test.exs")))
    }
  end

  defp priv_dir(root) do
    case :code.priv_dir(:ex4pm) do
      {:error, _} -> Path.join(root, "priv")
      dir -> List.to_string(dir)
    end
  end

  defp ferroplan_source_paths(root) do
    [
      "lib/ex4pm/engine/ferroplan*.ex",
      "lib/ex4pm/engine/ferroplan/**/*.ex",
      "lib/ex4pm/ferroplan*.ex",
      "lib/ex4pm/ferroplan/**/*.ex"
    ]
    |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
    |> Enum.uniq()
  end

  defp read_all(paths), do: Map.new(paths, &{&1, File.read!(&1)})

  # -- pure checks -----------------------------------------------------------

  @doc "All typed violations for `inputs` (see `load_inputs/1`); no known-gap filtering."
  @spec violations(map()) :: [violation()]
  def violations(inputs) do
    export_violations(inputs) ++
      Enum.flat_map(inputs.algorithms, &algorithm_violations(&1, inputs)) ++
      Enum.flat_map(inputs.ferroplan_ops, &ferroplan_violations(&1, inputs)) ++
      skipped_real_violations(inputs)
  end

  defp v(layer, subject, detail) do
    %{
      broken_term: "REFUSED_EXPOSURE_" <> (layer |> Atom.to_string() |> String.upcase()),
      layer: layer,
      subject: subject,
      detail: detail
    }
  end

  # --- export section vs registry

  defp export_violations(%{artifact_exports: {:error, reason}}),
    do: [v(:artifact_missing, {:wasm_export, "*"}, "cannot read artifact: #{inspect(reason)}")]

  defp export_violations(%{artifact_exports: {:ok, exported}, algorithms: specs}) do
    declared = Enum.flat_map(specs, &[&1.export_name, &1.replay_export_name])
    actual = exported -- @core_exports

    for(
      n <- declared -- actual,
      do: v(:export_drift, {:wasm_export, n}, "registry export absent from artifact")
    ) ++
      for n <- actual -- declared,
          do: v(:export_drift, {:wasm_export, n}, "artifact export has no registry row")
  end

  # --- algorithm layers

  defp algorithm_violations(spec, inputs) do
    %{module: module, algorithm_id: id} = spec
    subj = {:algorithm, id}

    adapter? =
      Code.ensure_loaded?(module) and function_exported?(module, :execute, 3) and
        function_exported?(module, :wasm_export, 0) and module.wasm_export() == spec.export_name

    engine_op? =
      module in inputs.engines and Code.ensure_loaded?(module) and
        function_exported?(module, :supports?, 2) and module.supports?(id, [])

    []
    |> add(
      not adapter?,
      v(
        :no_adapter,
        subj,
        "#{inspect(module)} missing or lacks execute/3 + wasm_export/0 == #{spec.export_name}"
      )
    )
    |> add(
      not engine_op?,
      v(
        :no_engine_op,
        subj,
        "#{inspect(module)} is not an Ex4pm.Engine.Registry candidate supporting #{inspect(id)}"
      )
    )
    |> add(
      not public_function?(spec, engine_op?),
      v(
        :no_public_function,
        subj,
        "not reachable through Ex4pm.capabilities/2 nor an Ex4pm.#{id} function"
      )
    )
    |> add(not moduledoc?(module), v(:no_doc, subj, "#{inspect(module)} has no @moduledoc"))
    |> add(
      not algorithm_real_test?(id, inputs.tests),
      v(
        :no_real_test,
        subj,
        "no test file references #{inspect(id)} (or iterates AlgoRegistry) with a real-artifact marker"
      )
    )
    |> Enum.reverse()
  end

  defp public_function?(%{module: module, algorithm_id: id}, engine_op?) do
    via_capabilities? =
      engine_op? and Code.ensure_loaded?(Ex4pm) and function_exported?(Ex4pm, :capabilities, 2) and
        Enum.any?(Ex4pm.capabilities(id, []), fn cap ->
          cap.id == module.id() and cap.standing != :unsupported
        end)

    via_capabilities? or
      (Code.ensure_loaded?(Ex4pm) and Enum.any?(0..4, &function_exported?(Ex4pm, id, &1)))
  end

  defp add(acc, true, violation), do: [violation | acc]
  defp add(acc, false, _), do: acc

  defp moduledoc?(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, %{} = doc, _, _} ->
        Enum.any?(doc, fn {_, t} -> String.trim(t) != "" end)

      _ ->
        false
    end
  end

  @real_marker ~r/WasmArtifact|RealTransport|real_wasm/

  defp algorithm_real_test?(id, tests) do
    word = ~r/(?<![a-z0-9_])#{id}(?![a-z0-9_])/

    Enum.any?(tests, fn {path, text} ->
      real_test_file?(path) and Regex.match?(@real_marker, text) and
        (Regex.match?(word, text) or
           Regex.match?(~r/AlgoRegistry\.(algorithm_ids|algo_specs)/, text))
    end)
  end

  defp real_test_file?(path), do: not String.ends_with?(path, "exposure_court_test.exs")

  # --- ferroplan layers

  defp ferroplan_violations("session_" <> name = op, inputs) do
    subj = {:ferroplan_op, op}
    session_ok? = session_op?(name)
    call_ok? = sessions_call?()

    []
    |> add(
      not session_ok?,
      v(
        :no_adapter,
        subj,
        "#{inspect(@session_module)}.ops/0 does not list \"#{name}\" (the session GenServer " <>
          "is the adapter for session_* ops)"
      )
    )
    |> add(
      not (session_ok? and call_ok?),
      v(
        :no_engine_op,
        subj,
        "session op \"#{name}\" not dispatchable through #{inspect(@sessions_module)}.call/4"
      )
    )
    |> add(
      not (call_ok? and sessions_function?(name)),
      v(
        :no_public_function,
        subj,
        "#{inspect(@sessions_module)}.call/4 (or its lifecycle function) is not exported"
      )
    )
    |> add(
      call_ok? and not fun_doc?({@sessions_module, :call, 4}),
      v(:no_doc, subj, "#{inspect(@sessions_module)}.call/4 has no @doc")
    )
    |> add(
      not session_real_test?(name, inputs.tests),
      v(
        :no_real_test,
        subj,
        "no ferroplan real-artifact test drives \"#{name}\" through #{inspect(@sessions_module)}"
      )
    )
    |> Enum.reverse()
  end

  defp ferroplan_violations(op, inputs) do
    subj = {:ferroplan_op, op}
    facts = ferroplan_facts(inputs.ferroplan_sources)
    unsupported = Map.get(facts.unsupported, op)
    fun = find_public_function(op, inputs.ferroplan_modules)

    []
    |> add(
      not MapSet.member?(facts.literals, op),
      v(:no_adapter, subj, "op literal \"#{op}\" appears in no ferroplan engine source")
    )
    |> add(
      not (MapSet.member?(facts.ops, op) or is_binary(unsupported)),
      v(
        :no_engine_op,
        subj,
        "op not in an engine ops table nor declared in @unsupported with a reason"
      )
    )
    |> add(
      not (is_binary(unsupported) and unsupported != "") and fun == nil,
      v(:no_public_function, subj, "no public facade function and no @unsupported reason")
    )
    |> add(
      not (is_binary(unsupported) and unsupported != "") and fun != nil and not fun_doc?(fun),
      v(:no_doc, subj, "facade function #{inspect(fun)} has no @doc")
    )
    |> add(
      not ferroplan_real_test?(op, inputs.tests),
      v(
        :no_real_test,
        subj,
        "no test file references \"#{op}\" (facade function, :ferroplan_#{op} or op string) " <>
          "with a ferroplan real-artifact marker"
      )
    )
    |> Enum.reverse()
  end

  # --- session ops (declared mapping, verified against the live modules)

  defp session_op?(name) do
    Code.ensure_loaded?(@session_module) and function_exported?(@session_module, :ops, 0) and
      name in @session_module.ops()
  end

  defp sessions_call?,
    do: Code.ensure_loaded?(@sessions_module) and function_exported?(@sessions_module, :call, 4)

  # lifecycle ops also have a dedicated function; the rest are reached via call/4
  defp sessions_function?(name) when name in ~w(new fork free) do
    Code.ensure_loaded?(@sessions_module) and
      Enum.any?(1..3, &function_exported?(@sessions_module, String.to_atom(name), &1))
  end

  defp sessions_function?(_), do: true

  # facade function names (besides call/4) that drive an op
  @session_facades %{
    "valid" => ["plan_valid?"],
    "goal_met" => ["goal_met?"],
    "think" => ["think"],
    "observe" => ["observe"],
    "suffix" => ["suffix"],
    "advance" => ["advance"],
    "new" => ["new"],
    "fork" => ["fork"],
    "free" => ["free"]
  }

  defp session_real_test?(name, tests) do
    facades = Map.get(@session_facades, name, [])

    facade_re =
      if facades == [],
        do: nil,
        else: Regex.compile!("Sessions\\.(?:#{Enum.join(facades, "|")})\\(")

    call_re =
      Regex.compile!(
        "Sessions\\.call\\(\\s*[^,()]+,\\s*(?::|\")(?:session_)?#{name}(?![a-z0-9_])"
      )

    Enum.any?(tests, fn {path, text} ->
      real_test_file?(path) and Regex.match?(@ferroplan_marker, text) and
        (Regex.match?(call_re, text) or (facade_re != nil and Regex.match?(facade_re, text)))
    end)
  end

  @doc false
  # AST facts from the ferroplan engine sources: non-doc string literals, the
  # strings in `@*ops` attributes, and the `@unsupported` op => reason map.
  def ferroplan_facts(sources) do
    Enum.reduce(
      sources,
      %{literals: MapSet.new(), ops: MapSet.new(), unsupported: %{}},
      fn {path, text}, acc ->
        case Code.string_to_quoted(text, file: path) do
          {:ok, ast} -> facts_from_ast(ast, acc)
          {:error, _} -> acc
        end
      end
    )
  end

  defp facts_from_ast(ast, acc) do
    {_, acc} =
      Macro.prewalk(ast, acc, fn
        {:@, _, [{name, _, _}]} = node, a when name in [:doc, :moduledoc, :typedoc] ->
          {nil_node(node), a}

        {:@, _, [{name, _, [val]}]} = node, a when is_atom(name) ->
          {node, attr_facts(Atom.to_string(name), val, a)}

        node, a when is_binary(node) ->
          {node, %{a | literals: put_tokens(a.literals, node)}}

        node, a ->
          {node, a}
      end)

    acc
  end

  defp nil_node(_), do: nil

  defp attr_facts(name, val, acc) do
    cond do
      name == "unsupported" ->
        %{acc | unsupported: Map.merge(acc.unsupported, unsupported_map(val))}

      String.ends_with?(name, "ops") ->
        %{acc | ops: strings(val) |> Enum.reduce(acc.ops, &put_tokens(&2, &1))}

      true ->
        acc
    end
  end

  defp unsupported_map({:%{}, _, pairs}) do
    for {k, r} <- pairs,
        key = key_string(k),
        into: %{},
        do: {key, if(is_binary(r), do: r, else: nil)}
  end

  defp unsupported_map(_), do: %{}

  defp key_string(k) when is_binary(k), do: k
  defp key_string(k) when is_atom(k), do: Atom.to_string(k)
  defp key_string(_), do: nil

  defp strings(ast) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        n, a when is_binary(n) -> {n, [n | a]}
        n, a -> {n, a}
      end)

    acc
  end

  defp put_tokens(set, string) do
    string |> String.split(~r/\s+/, trim: true) |> Enum.reduce(set, &MapSet.put(&2, &1))
  end

  defp find_public_function(op, modules) do
    names =
      [op, String.replace_prefix(op, "session_", "")] ++ Map.get(@function_aliases, op, [])

    for m <- modules, Code.ensure_loaded?(m), n <- Enum.uniq(names), a <- 0..5, reduce: nil do
      nil ->
        if function_exported?(m, String.to_atom(n), a), do: {m, String.to_atom(n), a}, else: nil

      found ->
        found
    end
  end

  defp fun_doc?({m, f, _a}) do
    case Code.fetch_docs(m) do
      {:docs_v1, _, _, _, _, _, entries} ->
        Enum.any?(entries, fn
          {{:function, ^f, _}, _, _, %{} = doc, _} ->
            Enum.any?(doc, fn {_, t} -> String.trim(t) != "" end)

          _ ->
            false
        end)

      _ ->
        false
    end
  end

  # A real test drives the op by facade function (`Ferroplan.<fn>(`), by engine
  # op atom (`:ferroplan_<fn>`) or by its manifest string -- the facade/engine
  # names may differ from the ABI op (`htn_plan` -> `hierarchical_plan`).
  defp ferroplan_real_test?(op, tests) do
    names = Enum.uniq([op | Map.get(@function_aliases, op, [])])
    alt = Enum.map_join(names, "|", &Regex.escape/1)

    drives =
      Regex.compile!(
        "\"#{Regex.escape(op)}\"|Ferroplan\\.(?:#{alt})\\(|:ferroplan_(?:#{alt})(?![a-z0-9_])"
      )

    Enum.any?(tests, fn {path, text} ->
      real_test_file?(path) and Regex.match?(@ferroplan_marker, text) and
        Regex.match?(drives, text)
    end)
  end

  # --- skipped real exec (LieFinder rule)

  defp skipped_real_violations(%{tests: tests}) do
    for {path, text} <- tests,
        finding <- Ex4pm.Qualification.LieFinder.scan_test_source(path, text) do
      v(:skipped_real_exec, {:test_file, path}, finding.message)
    end
  end

  # -- real execution (`--require-real`) --------------------------------------

  @fp_domain """
  (define (domain blocks)
    (:requirements :strips)
    (:predicates (on-table ?x) (clear ?x) (holding ?x) (hand-empty) (on ?x ?y))
    (:action pick-up
      :parameters (?x)
      :precondition (and (clear ?x) (on-table ?x) (hand-empty))
      :effect (and (not (on-table ?x)) (not (clear ?x)) (not (hand-empty)) (holding ?x)))
    (:action put-down
      :parameters (?x)
      :precondition (holding ?x)
      :effect (and (not (holding ?x)) (clear ?x) (hand-empty) (on-table ?x))))
  """

  @fp_problem """
  (define (problem p1)
    (:domain blocks)
    (:objects a)
    (:init (clear a) (on-table a) (hand-empty))
    (:goal (holding a)))
  """

  @doc """
  Executes every registered algorithm through the bundled wasm4pm artifact
  (canonical request, real Wasmex, replay re-executed) and the ferroplan core
  ops (`version`, `readiness`, `plan` on an embedded PDDL fixture) through the
  bundled ferroplan artifact. Any result that is not `:alive` is a
  `REFUSED_EXPOSURE_NOT_ALIVE` violation. Returns `{violations, executed}`.
  """
  @spec real_violations(map(), keyword()) :: {[violation()], [map()]}
  def real_violations(inputs, opts \\ []) do
    {a_viol, a_exec} = real_algorithms(inputs, opts)
    {f_viol, f_exec} = real_ferroplan(inputs, opts)
    {a_viol ++ f_viol, a_exec ++ f_exec}
  end

  defp real_algorithms(inputs, opts) do
    artifact =
      Keyword.get(
        opts,
        :wasm_artifact,
        Path.join([inputs.priv_dir, "wasm4pm", "wasm4pm_ex4pm_bindings.wasm"])
      )

    case RealTransport.all_transports(artifact) do
      {:ok, transports} ->
        requests = CanonicalRequests.requests()

        results =
          for spec <- inputs.algorithms do
            id = spec.algorithm_id
            subj = {:algorithm, id}

            outcome =
              case Map.fetch(requests, id) do
                :error ->
                  {:violation, v(:not_alive, subj, "no canonical request embedded for #{id}")}

                {:ok, req} ->
                  run_algorithm(spec, req, transports, subj)
              end

            outcome
          end

        {for({:violation, x} <- results, do: x), for({:executed, x} <- results, do: x)}

      {:error, reason} ->
        {[
           v(
             :artifact_missing,
             {:wasm_export, "*"},
             "cannot admit/start #{artifact}: #{inspect(reason)}"
           )
         ], []}
    end
  end

  defp run_algorithm(spec, req, transports, subj) do
    case spec.module.execute(spec.algorithm_id, req, transports) do
      {:ok, %{standing: :alive} = result} ->
        {:executed, %{subject: subj, standing: :alive, replay_verified: replay_verified?(result)}}

      {:ok, %{standing: standing}} ->
        {:violation, v(:not_alive, subj, "standing #{inspect(standing)}, expected :alive")}

      other ->
        {:violation,
         v(:not_alive, subj, "execute returned #{inspect(other, limit: 5, printable_limit: 200)}")}
    end
  rescue
    e -> {:violation, v(:not_alive, subj, "raised #{Exception.message(e)}")}
  end

  defp replay_verified?(%{evidence: %{} = ev}), do: Map.get(ev, :replay_verified, true)
  defp replay_verified?(_), do: true

  defp real_ferroplan(inputs, opts) do
    fp = Ex4pm.Engine.Ferroplan

    fp_opts =
      case Keyword.fetch(opts, :ferroplan_artifact) do
        {:ok, p} ->
          [ferroplan_artifact: p]

        :error ->
          [ferroplan_artifact: Path.join([inputs.priv_dir, "ferroplan", "ferroplan_wasm.wasm"])]
      end

    calls = [
      {"version", :ferroplan_version, %{}},
      {"readiness", :ferroplan_readiness, %{}},
      {"plan", :ferroplan_plan, %{domain: @fp_domain, problem: @fp_problem}}
    ]

    results =
      for {op, operation, subject} <- calls, op in inputs.ferroplan_ops do
        subj = {:ferroplan_op, op}

        try do
          case fp.execute(operation, subject, fp_opts) do
            {:ok, %{standing: :alive}} ->
              {:executed, %{subject: subj, standing: :alive}}

            {:ok, %{standing: s}} ->
              {:violation, v(:not_alive, subj, "standing #{inspect(s)}")}

            other ->
              {:violation,
               v(
                 :not_alive,
                 subj,
                 "execute returned #{inspect(other, limit: 5, printable_limit: 200)}"
               )}
          end
        rescue
          e -> {:violation, v(:not_alive, subj, "raised #{Exception.message(e)}")}
        end
      end

    {for({:violation, x} <- results, do: x), for({:executed, x} <- results, do: x)}
  end

  # -- run --------------------------------------------------------------------

  @doc """
  Runs the court. Options: `:require_real` (boolean), `:root`, `:known_gaps` (test seam, defaults
  to `known_gaps/0`), plus the
  artifact overrides accepted by `real_violations/2`.

  Returns `{:ok, receipt}` or `{:refused, violations}`; the receipt carries the
  tolerated known gaps and stale known-gap entries.
  """
  @spec run(keyword()) :: {:ok, map()} | {:refused, [violation()]}
  def run(opts \\ []) do
    inputs = load_inputs(opts)
    all = violations(inputs)
    gaps = Keyword.get(opts, :known_gaps, @known_gaps)

    {real, executed} =
      if Keyword.get(opts, :require_real, false),
        do: real_violations(inputs, opts),
        else: {[], []}

    {tolerated, new} = Enum.split_with(all, &known?(&1, gaps))
    stale = Enum.reject(gaps, fn gap -> Enum.any?(all, &matches?(gap, &1)) end)
    refused = new ++ real ++ Enum.map(stale, &stale_violation/1)

    if refused == [] do
      {:ok,
       %{
         subjects: %{
           algorithms: length(inputs.algorithms),
           wasm_exports: length(inputs.algorithms) * 2,
           ferroplan_ops: length(inputs.ferroplan_ops)
         },
         mode: if(Keyword.get(opts, :require_real, false), do: :require_real, else: :static),
         executed: executed,
         known_gaps: tolerated,
         stale_known_gaps: []
       }}
    else
      {:refused, refused}
    end
  end

  defp stale_violation({layer, matcher, owner} = gap) do
    v(
      :stale_known_gap,
      {:known_gap, inspect(gap)},
      "known gap #{inspect({layer, matcher})} (#{owner}) matches no violation: delete it"
    )
  end

  defp known?(violation, gaps), do: Enum.any?(gaps, &matches?(&1, violation))

  defp matches?({layer, matcher, _owner}, %{layer: layer, subject: subject}),
    do: matcher_hit?(matcher, subject)

  defp matches?(_, _), do: false

  defp matcher_hit?({:all_algorithms}, {:algorithm, _}), do: true
  defp matcher_hit?({:algorithm, id}, {:algorithm, id}), do: true
  defp matcher_hit?({:ferroplan_op, op}, {:ferroplan_op, op}), do: true

  defp matcher_hit?({:ferroplan_op_prefix, p}, {:ferroplan_op, op}),
    do: String.starts_with?(op, p)

  defp matcher_hit?({:test_file_suffix, suffix}, {:test_file, path}),
    do: String.ends_with?(path, suffix)

  defp matcher_hit?(_, _), do: false

  # -- wasm export section parser ----------------------------------------------

  @doc "Names of all exports (functions, memory, ...) in a wasm binary's export section."
  @spec wasm_exports(binary()) :: [String.t()]
  def wasm_exports(<<0, "asm", 1, 0, 0, 0, rest::binary>>), do: sections(rest, [])

  defp sections(<<>>, acc), do: Enum.reverse(acc)

  defp sections(<<id, rest::binary>>, acc) do
    {size, rest} = leb(rest)
    <<body::binary-size(size), rest::binary>> = rest

    case id do
      7 ->
        {n, b} = leb(body)
        sections(rest, read_exports(n, b, acc))

      _ ->
        sections(rest, acc)
    end
  end

  defp read_exports(0, _, acc), do: acc

  defp read_exports(n, bin, acc) do
    {len, bin} = leb(bin)
    <<name::binary-size(len), _kind, bin::binary>> = bin
    {_idx, bin} = leb(bin)
    read_exports(n - 1, bin, [name | acc])
  end

  defp leb(bin), do: leb(bin, 0, 0)

  defp leb(<<1::1, v::7, rest::binary>>, acc, shift),
    do: leb(rest, Bitwise.bor(acc, Bitwise.bsl(v, shift)), shift + 7)

  defp leb(<<0::1, v::7, rest::binary>>, acc, shift),
    do: {Bitwise.bor(acc, Bitwise.bsl(v, shift)), rest}
end

defmodule Ex4pm.Qualification.ExposureCourt.CanonicalRequests do
  @moduledoc """
  One small canonical request per registered algorithm (all 33), used by
  `Ex4pm.Qualification.ExposureCourt` in `--require-real` mode. Copied from
  the shapes validated against the wasm4pm-ex4pm-bindings crate's own tests.
  """

  @doc "Canonical request map keyed by algorithm id."
  @spec requests() :: %{atom() => map()}
  def requests do
    %{
      discover: %{traces: [["a", "b", "c"], ["a", "b"]]},
      conform: %{traces: [["a", "b"], ["a", "c"]], model_edges: [%{from: "a", to: "b"}]},
      simulate: %{
        edges: [%{from: "a", to: "b"}, %{from: "a", to: "c"}],
        start: "a",
        steps: 1,
        seed: 42
      },
      optimize: %{
        edges: [
          %{from: "a", to: "b", duration: 1.0},
          %{from: "b", to: "c", duration: 5.0},
          %{from: "a", to: "c", duration: 2.0}
        ],
        start: "a",
        end: "c"
      },
      powl_mine: %{traces: [["a", "b"], ["a", "b"]]},
      survival: %{times: [1.0, 2.0, 3.0, 4.0], events: [1.0, 1.0, 0.0, 1.0]},
      markov: %{transition_matrix: [0.5, 0.5, 0.5, 0.5], n_states: 2, max_iter: 100, tol: 1.0e-9},
      bayesian: %{data: [1.0, 2.0, 3.0, 4.0], n_features: 1, targets: [2.0, 4.0, 6.0, 8.0]},
      ocpq_eval: %{
        query: %{root: "n0", nodes: [%{id: "n0", box: %{}}]},
        ocel: %{objectTypes: [], eventTypes: [], objects: [], events: []}
      },
      strips_plan: %{
        intent: "test",
        candidates: [],
        facts: [],
        cases: [],
        rules: [],
        goals: [],
        state: []
      },
      htn_plan: %{
        intent: "test",
        candidates: [],
        facts: [],
        cases: [],
        rules: [],
        goals: [],
        state: []
      },
      ctl_check: %{
        intent: "test",
        candidates: [],
        cases: [],
        rules: [],
        goals: [],
        state: [],
        facts: [
          %{key: "ts:init", value: "s0"},
          %{key: "ts:edge:s0", value: "s1"},
          %{key: "ts:edge:s1", value: "s1"},
          %{key: "ts:label:s1", value: "done"},
          %{key: "ctl:formula", value: "E F done"}
        ]
      },
      allen_temporal: %{
        intent: "test",
        candidates: [],
        facts: [],
        cases: [],
        rules: [],
        goals: [],
        state: []
      },
      oc_discover: %{
        ocel: %{
          event_types: ["A", "B"],
          object_types: ["Order"],
          events: [
            %{
              id: "e1",
              event_type: "A",
              timestamp: "2024-01-01T10:00:00Z",
              attributes: %{},
              object_ids: ["order1"],
              object_refs: []
            },
            %{
              id: "e2",
              event_type: "B",
              timestamp: "2024-01-01T11:00:00Z",
              attributes: %{},
              object_ids: ["order1"],
              object_refs: []
            }
          ],
          objects: [
            %{
              id: "order1",
              object_type: "Order",
              attributes: %{},
              changes: [],
              embedded_relations: []
            }
          ],
          object_relations: []
        },
        algorithm: "alpha++"
      },
      align: %{
        traces: [["a", "b"]],
        petri_net: %{
          places: [%{id: "p0", label: "p0"}, %{id: "p1", label: "p1"}, %{id: "p2", label: "p2"}],
          transitions: [%{id: "t0", label: "a"}, %{id: "t1", label: "b"}],
          arcs: [
            %{from: "p0", to: "t0"},
            %{from: "t0", to: "p1"},
            %{from: "p1", to: "t1"},
            %{from: "t1", to: "p2"}
          ],
          initial_marking: %{p0: 1},
          final_markings: [%{p2: 1}]
        },
        sync_cost: 0.0,
        log_move_cost: 1.0,
        model_move_cost: 1.0
      },
      etc_precision: %{
        net: %{
          places: [%{id: "p0", label: "p0"}, %{id: "p1", label: "p1"}],
          transitions: [%{id: "t0", label: "a"}],
          arcs: [%{from: "p0", to: "t0"}, %{from: "t0", to: "p1"}],
          initial_marking: %{p0: 1},
          final_markings: [%{p1: 1}]
        },
        initial_marking: %{p0: 1},
        final_marking: %{p1: 1},
        log: %{attributes: %{}, traces: []},
        activity_key: "concept:name"
      },
      soundness: %{
        petri_net: %{
          places: [%{id: "p0", label: "p0"}, %{id: "p1", label: "p1"}, %{id: "p2", label: "p2"}],
          transitions: [%{id: "t0", label: "a"}, %{id: "t1", label: "b"}],
          arcs: [
            %{from: "p0", to: "t0"},
            %{from: "t0", to: "p1"},
            %{from: "p1", to: "t1"},
            %{from: "t1", to: "p2"}
          ],
          initial_marking: %{p0: 1},
          final_markings: [%{p2: 1}]
        }
      },
      playout: %{
        petri_net: %{
          places: [
            %{id: "p1", label: "start", marking: 1},
            %{id: "p2", label: "middle", marking: 0},
            %{id: "p3", label: "end", marking: 0}
          ],
          transitions: [
            %{id: "t1", label: "a", is_invisible: false},
            %{id: "t2", label: "b", is_invisible: false}
          ],
          arcs: [
            %{from: "p1", to: "t1", weight: 1},
            %{from: "t1", to: "p2", weight: 1},
            %{from: "p2", to: "t2", weight: 1},
            %{from: "t2", to: "p3", weight: 1}
          ],
          initial_marking: %{p1: 1},
          final_markings: [%{p3: 1}]
        },
        config: %{max_trace_length: 10, num_traces: 5, random_seed: 7}
      },
      prolog_query: %{
        predicates: [%{name: "parent", arity: 2}],
        facts: [%{pred: "parent", args: ["alice", "bob"]}],
        rules: [],
        query: %{pred: "parent", args: ["alice", "Y"]}
      },
      # Phase 4 (statistics/ML) -- canonical requests cross-checked against
      # wasm4pm-ex4pm-bindings' own real Rust unit tests
      # (crates/wasm4pm-ex4pm-bindings/src/phase4_stats.rs, tests module).
      ks_statistic: %{sample_a: [1.0, 2.0, 3.0], sample_b: [1.0, 2.0, 3.0]},
      ks_critical_value: %{n: 10, m: 10, alpha: 0.05},
      regression: %{x: [1.0, 2.0, 3.0, 4.0], y: [2.0, 4.0, 6.0, 8.0]},
      forecast: %{data: [1.0, 2.0, 3.0, 4.0, 5.0], alpha: 0.3},
      holt_forecast: %{series: [1.0, 2.0, 3.0, 4.0, 5.0], alpha: 0.5, beta: 0.5},
      ewma: %{values: [1.0, 5.0, 10.0], alpha: 1.0},
      trend_classify: %{smoothed: [1.0, 2.0, 3.0, 4.0, 5.0]},
      mean: %{data: [1.0, 2.0, 3.0, 4.0]},
      dot_product: %{a: [1.0, 2.0, 3.0], b: [4.0, 5.0, 6.0]},
      euclidean_distance: %{a: [0.0, 0.0], b: [3.0, 4.0]},
      standardize: %{data: [[1.0, 10.0], [2.0, 20.0], [3.0, 30.0]]},
      median: %{data: [3.0, 1.0, 2.0]},
      percentile: %{data: [1.0, 2.0, 3.0, 4.0], p: 50.0},
      std_deviation: %{data: [5.0, 5.0, 5.0]}
    }
  end
end
