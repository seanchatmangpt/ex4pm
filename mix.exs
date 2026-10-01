defmodule Ex4pm.MixProject do
  use Mix.Project

  # Zero-config requirement: Ash requires `config :ash,
  # default_string_length_count` for any Ash.Resource using :string/:ci_string
  # constraints, and a dependency's own config/config.exs is never loaded by
  # a consuming app's build -- only the top-level project's config is. Set
  # the default here instead, since Mix always evaluates a dependency's
  # mix.exs (which runs this module body) before compiling its lib/, whether
  # ex4pm is the top-level project or a `path:`/hex dependency of another
  # app. A consumer that has already set this value keeps their own choice.
  # Read dynamically: Application.compile_env/3 does not apply inside mix.exs, and the
  # direct get_env/2 call trips Elixir's module-body lint under --warnings-as-errors.
  if is_nil(apply(Application, :get_env, [:ash, :default_string_length_count])) do
    Application.put_env(:ash, :default_string_length_count, :codepoints)
  end

  @version "26.9.30"
  @source_url "https://github.com/seanchatmangpt/ex4pm"

  def project do
    [
      app: :ex4pm,
      version: @version,
      elixir: "~> 1.17",
      description:
        "BEAM-native, evidence-oriented process intelligence: OCEL/XES ingest, " <>
          "POWL discovery/conformance/simulation, BRCE-gated DO, receipts and replay.",
      source_url: @source_url,
      package: package(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: [
        verify: :test,
        "test.stress": :test,
        "test.integration": :test,
        chicago: :test,
        "ex4pm.powl.court": :test,
        "ex4pm.sabotage.court": :test,
        "ex4pm.lint.truth": :test,
        "ex4pm.crown": :test,
        "ex4pm.release.contract": :test,
        "ex4pm.rails.court": :test
      ],
      dialyzer: [
        plt_core_path: "priv/plts/core.plt",
        plt_file: {:no_warn, "priv/plts/project.plt"},
        plt_add_apps: [:ex_unit, :mix]
      ]
    ]
  end

  def application do
    [
      mod: {Ex4pm.Application, []},
      extra_applications: [:logger, :crypto, :xmerl]
    ]
  end

  def cli do
    [
      preferred_envs: [
        verify: :test,
        "test.stress": :test,
        "test.integration": :test,
        chicago: :test,
        "ex4pm.powl.court": :test,
        "ex4pm.sabotage.court": :test,
        "ex4pm.lint.truth": :test,
        "ex4pm.crown": :test,
        "ex4pm.release.contract": :test,
        "ex4pm.rails.court": :test
      ]
    ]
  end

  defp elixirc_paths(:test),
    do: ["lib", "test/support", "test/demo_web/lib", "test/demo_web/test/support"]

  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Ash / evidence-domain plane. ash_admin (and the ash_phoenix it pulls
      # in transitively via cinder) is a real lib/ compile-time dep — 8
      # Ash.Domain/Resource modules use its `admin do ... end` DSL extension
      # directly. It's what forces `config :ash, default_string_length_count`
      # on any compile; the top of this file sets that default itself
      # (Mix always evaluates a dep's mix.exs before compiling its lib/) so
      # a consumer never has to configure it.
      {:ash, "~> 3.31"},
      # Bumped to match consumers (e.g. xaas) that pull ex4pm in as a path
      # dep and resolve a unified dep tree at ash_admin ~> 1.3 -- this
      # module's own `admin do show?(true) end` block has no 0.12-only API
      # usage, so the bump is compile-compatible.
      {:ash_admin, "~> 1.3"},
      {:ash_phoenix, "~> 2.1"},
      {:ash_state_machine, "~> 0.2.13"},

      # OCEL/XES core
      {:sweet_xml, "~> 0.7.5"},

      # DfCM engine
      {:wasmex, "~> 0.14"},
      # Zero-config Ash JSON:API client transport for Ex4pm.Engine.Beam4pm
      # (docs/EX4PM-THINNING-BEAM4PM-ENRICHMENT.md) -- deliberately Req,
      # not wasmex/rustler: pure-Elixir HTTP stack (finch/mint), no native
      # toolchain, consistent with the "ex4pm thinning" goal this engine
      # candidate itself exists to serve.
      {:req, "~> 0.5"},
      # Additive A2A.Client-based path to beam4pm's newly-mounted A2A agent
      # (Ex4pm.Engine.Beam4pmA2A) -- alongside, not replacing,
      # Ex4pm.Engine.Beam4pm's existing hand-rolled JSON:API route-table
      # client above. Client-side role only needs the `:a2a` package
      # itself (A2A.Client), not `:ash_a2a` (server-side Spark DSL
      # extension that beam4pm, not ex4pm, uses to expose its skills).
      {:a2a, "~> 0.2"},
      {:explorer, "~> 0.12"},
      {:reactor, "~> 1.0"},
      {:postgrex, "~> 0.22.4"},
      {:decimal, "~> 3.1"},

      # Stream ingestion
      {:broadway, "~> 1.3"},
      {:plug, "~> 1.14"},
      {:telemetry_metrics_prometheus_core, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6 or ~> 1.0"},

      # Runtime (POWL execution state machine)
      {:gen_state_machine, "~> 3.0"},

      # Shared
      {:jason, "~> 1.4.5"},
      {:stream_data, "~> 1.0"},

      # Dev/test only
      {:igniter, "~> 0.8.3", only: [:dev, :test]},
      {:faker, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      # Manufacturing-time tool only (`mix ggen_igniter.sync`) -- never a
      # runtime dependency of generated code, matching beam4pm's own
      # dependency line exactly (mix.exs there: {:ggen_igniter, "~> 26.8",
      # only: [:dev, :test], runtime: false}). R0 of docs/PRD-v26.9.10.md.
      {:ggen_igniter, "~> 26.9", only: [:dev, :test], runtime: false},

      # ash_admin's own LiveView UI needs Phoenix/LiveView to compile even
      # though nothing outside ash_admin uses them directly.
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_pubsub, "~> 2.1"},

      # test/demo_web (Phoenix/LiveView demo harness) only
      {:bandit, "~> 1.5", only: :test},
      {:telemetry_poller, "~> 1.0", only: :test},

      # Real AshJsonApi-backed local "micro beam4pm" (test/support/micro_beam4pm.ex)
      # for Ex4pm.Engine.Beam4pm's Chicago-style tests -- exercises the REAL
      # AshJsonApi wire format (route shape, index/get conventions, JSON:API
      # response envelope) instead of a hand-guessed fake, since beam4pm's own
      # future json_api exposure (docs/BEAM4PM-OPENAPI-GGEN-IGNITER-PLAN.md)
      # will use this exact library. Test-only: production never mounts this.
      {:ash_json_api, "~> 1.7", only: :test},
      # Real finding, confirmed empirically this session: ash_json_api's
      # own OpenAPI emission (`AshJsonApi.Router`'s `open_api:` option)
      # silently 404s without this -- `open_api_spex` is declared optional
      # in ash_json_api's own mix.exs and is NOT pulled in transitively
      # just by depending on ash_json_api. Confirms/sharpens the
      # "UNVERIFIED" flag in docs/BEAM4PM-OPENAPI-GGEN-IGNITER-PLAN.md:
      # beam4pm's own future mix.exs will need this dep explicitly too.
      {:open_api_spex, "~> 3.16", only: :test},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "docs/guides/real-wasm.md",
        "docs/guides/planning-with-ferroplan.md",
        "docs/guides/choosing-an-engine.md",
        "docs/ARCHITECTURE.md",
        "docs/FERROPLAN-RUNTIME.md",
        "docs/ALGORITHM-REGISTRY-GENERATION.md",
        "docs/ARD-v26.9.x-wasm4pm-phase1.md",
        "CHANGELOG.md",
        "docs/consumer/tutorials.md",
        "docs/consumer/how-to-guides.md",
        "docs/consumer/reference.md",
        "docs/consumer/explanation.md"
      ],
      groups_for_extras: [
        Guides: ~r{^docs/guides/},
        "WASM and planning": [
          "docs/FERROPLAN-RUNTIME.md",
          "docs/ALGORITHM-REGISTRY-GENERATION.md",
          "docs/ARD-v26.9.x-wasm4pm-phase1.md"
        ],
        "Consumer Guide": Path.wildcard("docs/consumer/*.md")
      ],
      groups_for_modules: [
        "Public API": [Ex4pm, Ex4pm.Engine, Ex4pm.Engine.Result, Ex4pm.Refusal, Ex4pm.Contracts],
        Ferroplan: [Ex4pm.Engine.Ferroplan, Ex4pmEngine.Wasm.FerroplanTransport],
        "WASM engines": [
          Ex4pm.Engine.Wasm,
          Ex4pm.Engine.WasmRemote,
          Ex4pmEngine.Wasm.Admission,
          Ex4pmEngine.Wasm.RealTransport,
          Ex4pmEngine.Wasm.Host,
          Ex4pmEngine.Wasm.AlgoRegistry,
          Ex4pmEngine.Wasm.Adapter
        ],
        "WASM adapters": ~r/^Ex4pmEngine\.Wasm\./,
        "Other engines": [
          Ex4pm.Engine.Beam,
          Ex4pm.Engine.Beam4pm,
          Ex4pm.Engine.Beam4pmA2A,
          Ex4pm.Engine.Ex4pmPlan,
          Ex4pm.Engine.CmcaWasm,
          Ex4pm.Engine.NifCandidate,
          Ex4pm.Engine.Remote,
          Ex4pm.Engine.Differential
        ],
        "Evidence / BRCE": [~r/^Ex4pm\.Evidence\./, ~r/^Ex4pmEvidence\./],
        Core: [~r/^Ex4pm\.Core/, ~r/^Ex4pmCore\./, Ex4pm.Standing],
        Domain: [~r/^Ex4pm\.Domain/, ~r/^Ex4pmDomain\./],
        "Information / Reactor": [~r/^Ex4pm\.Information/, ~r/^Ex4pmEngine\.Reactors/],
        Qualification: [~r/^Ex4pm\.Qualification/, ~r/^Mix\.Tasks\./],
        "Runtime and streaming": [~r/^Ex4pm\.Runtime/, ~r/^Ex4pm\.Stream/],
        "Process engines (Ex4pmEngine)": ~r/^Ex4pmEngine\./,
        "Compat types": ~r/^Wasm4pmCompat\./
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Architecture" => @source_url <> "/blob/main/docs/ARCHITECTURE.md"
      },
      files: ["lib", "priv", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end

  defp falsify_wasm(args) do
    {_, code} =
      System.cmd("bash", ["scripts/falsify-wasm-e2e.sh" | args],
        into: IO.stream(:stdio, :line),
        stderr_to_stdout: true
      )

    if code != 0, do: Mix.raise("falsify.wasm failed with exit #{code}")
  end

  defp aliases do
    [
      verify: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "ex4pm.lint.truth",
        # Real, automated determinism proof for every ggen_igniter-generated
        # file in priv/ggen/manifest.json (delete/regenerate/byte-diff) --
        # no-ops cleanly if the manifest doesn't exist yet, per the task's
        # own moduledoc. Closes the gap PRD-v26.9.10.md named: this claim
        # used to be proven manually, once, and never re-checked.
        "ex4pm.ggen.verify_determinism --all",
        # verify is the full gate -- :integration/:stress are excluded from plain
        # `mix test` for a fast default inner loop (see test/test_helper.exs),
        # but must still run here so verify's own coverage doesn't silently
        # shrink.
        "test --include integration --include stress",
        "ex4pm.powl.court",
        "ex4pm.sabotage.court",
        "ex4pm.ggen.verify_determinism --all"
      ],
      "test.stress": [
        "test test/benchmarks/stress_benchmark_test.exs test/benchmarks/wasm_engine_benchmark_test.exs --include stress"
      ],
      "test.integration": [
        "test --include integration"
      ],
      chicago: ["test --only chicago --seed 0"],
      # Real end-to-end WASM falsifier: regen -> build wasm32 -> real Wasmex tests.
      # Exit codes documented in scripts/falsify-wasm-e2e.sh.
      "falsify.wasm": [&falsify_wasm/1]
    ]
  end
end
