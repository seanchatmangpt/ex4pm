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
  if is_nil(Application.get_env(:ash, :default_string_length_count)) do
    Application.put_env(:ash, :default_string_length_count, :codepoints)
  end

  @version "26.9.9"
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
        chicago: :test,
        "ex4pm.powl.court": :test,
        "ex4pm.sabotage.court": :test,
        "ex4pm.lint.truth": :test,
        "ex4pm.crown": :test
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
        chicago: :test,
        "ex4pm.powl.court": :test,
        "ex4pm.sabotage.court": :test,
        "ex4pm.lint.truth": :test,
        "ex4pm.crown": :test
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

      # ash_admin's own LiveView UI needs Phoenix/LiveView to compile even
      # though nothing outside ash_admin uses them directly.
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_pubsub, "~> 2.1"},

      # test/demo_web (Phoenix/LiveView demo harness) only
      {:bandit, "~> 1.5", only: :test},
      {:telemetry_poller, "~> 1.0", only: :test},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "docs/ARCHITECTURE.md",
        "docs/consumer/tutorials.md",
        "docs/consumer/how-to-guides.md",
        "docs/consumer/reference.md",
        "docs/consumer/explanation.md"
      ],
      groups_for_extras: [
        "Consumer Guide": Path.wildcard("docs/consumer/*.md")
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
      files: ["lib", "priv", "mix.exs"]
    ]
  end

  defp aliases do
    [
      verify: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "ex4pm.lint.truth",
        "test",
        "ex4pm.powl.court",
        "ex4pm.sabotage.court"
      ],
      "test.stress": [
        "test test/benchmarks/stress_benchmark_test.exs test/benchmarks/wasm_engine_benchmark_test.exs --include stress"
      ],
      chicago: ["test --only chicago --seed 0"]
    ]
  end
end
