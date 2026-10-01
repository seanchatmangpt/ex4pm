defmodule Ex4pm.CLI do
  @moduledoc """
  CLI projection over the canonical ex4pm API.

  Subcommands: `doctor`, `contracts`, `discover`, `discover-xes`, `health`,
  `wasm verify`, `ferroplan version|readiness|plan <domain.pddl> <problem.pddl>`,
  `forecast <json>`, `help`. Failures print a typed refusal to stderr and exit 1.
  """

  def main(args) do
    case args do
      ["doctor"] ->
        doctor()

      ["contracts"] ->
        contracts()

      ["discover", path] ->
        discover_json(path, [])

      ["discover", path, object_type] ->
        discover_json(path, object_type: object_type)

      ["discover-xes", path] ->
        discover_xes(path, [])

      ["discover-xes", path, case_object_type] ->
        discover_xes(path, case_object_type: case_object_type)

      ["health"] ->
        health()

      ["wasm", "verify"] ->
        wasm_verify()

      ["ferroplan", "version"] ->
        ferroplan_json(:version, %{})

      ["ferroplan", "readiness"] ->
        ferroplan_json(:readiness, %{})

      ["ferroplan", "plan", domain, problem] ->
        ferroplan_plan(domain, problem)

      ["forecast", json] ->
        forecast(json)

      ["help"] ->
        help(0)

      [] ->
        help(0)

      _ ->
        help(2)
    end
  end

  defp doctor do
    payload =
      Ex4pm.capabilities(:discover)
      |> Enum.map(fn capability ->
        %{
          engine: capability.id,
          standing: capability.standing,
          reason: capability.reason,
          constraints: capability.constraints
        }
      end)

    ferroplan =
      :ferroplan_plan
      |> Ex4pm.capabilities()
      |> Enum.filter(&(&1.id == :ferroplan))
      |> Enum.map(fn capability ->
        %{engine: capability.id, standing: capability.standing, reason: capability.reason}
      end)

    contract =
      case Ex4pm.contracts() do
        {:ok, verified} -> %{standing: verified.standing, hash: verified.contract_hash}
        {:error, refusal} -> %{standing: :blocked, refusal: inspect(refusal)}
      end

    IO.puts(
      Jason.encode!(
        %{operation: :discover, candidates: payload, ferroplan: ferroplan, contracts: contract},
        pretty: true
      )
    )
  end

  defp health do
    IO.puts(Jason.encode!(to_json(Ex4pm.health()), pretty: true))
  end

  defp wasm_verify do
    {verdict, report} = Ex4pm.Wasm.Verify.run()
    IO.puts(Jason.encode!(to_json(report), pretty: true))
    if verdict == :error, do: fail("ex4pm wasm verify refused", report.refusal)
  end

  defp ferroplan_plan(domain_path, problem_path) do
    with {:ok, domain} <- File.read(domain_path),
         {:ok, problem} <- File.read(problem_path) do
      ferroplan_json(:plan, %{domain: domain, problem: problem})
    else
      {:error, reason} -> fail("ex4pm ferroplan plan refused/failed", reason)
    end
  end

  defp ferroplan_json(op, subject) do
    case Ex4pm.ferroplan(op, subject) do
      {:ok, run} -> print_run_json(run)
      {:error, reason} -> fail("ex4pm ferroplan #{op} refused/failed", reason)
    end
  end

  defp forecast(json) do
    with {:ok, decoded} <- Jason.decode(json),
         {:ok, series, opts} <- forecast_input(decoded),
         {:ok, run} <- Ex4pm.forecast(series, opts) do
      print_run_json(run)
    else
      {:error, reason} -> fail("ex4pm forecast refused/failed", reason)
    end
  end

  defp forecast_input(series) when is_list(series), do: {:ok, series, []}

  defp forecast_input(%{"series" => series} = map) when is_list(series) do
    opts =
      [
        method: map["method"] && String.to_existing_atom(map["method"]),
        alpha: map["alpha"],
        beta: map["beta"]
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    {:ok, series, opts}
  rescue
    ArgumentError -> {:error, :invalid_forecast_method}
  end

  defp forecast_input(_),
    do: {:error, :forecast_input_must_be_a_json_array_or_object_with_series}

  defp contracts do
    case Ex4pm.contracts() do
      {:ok, contract} -> IO.puts(Jason.encode!(json_safe(contract), pretty: true))
      {:error, reason} -> fail("ex4pm contracts refused/failed", reason)
    end
  end

  defp discover_json(path, opts) do
    with {:ok, bytes} <- File.read(path),
         {:ok, raw} <- Jason.decode(bytes),
         {:ok, run} <- Ex4pm.discover(raw, opts) do
      print_run(run)
    else
      {:error, reason} -> fail("ex4pm discover refused/failed", reason)
    end
  end

  defp discover_xes(path, opts) do
    with {:ok, bytes} <- File.read(path),
         {:ok, log} <- Ex4pm.ingest_xes(bytes, opts),
         {:ok, run} <-
           Ex4pm.discover(log, object_type: Keyword.get(opts, :case_object_type, "Case")) do
      print_run(run)
    else
      {:error, reason} -> fail("ex4pm discover-xes refused/failed", reason)
    end
  end

  defp print_run(run) do
    IO.puts(
      Jason.encode!(
        %{
          standing: run.standing,
          receipt: run.receipt.hash,
          model: json_safe(run.value)
        },
        pretty: true
      )
    )
  end

  defp print_run_json(run) do
    IO.puts(
      Jason.encode!(
        to_json(%{standing: run.standing, receipt: run.receipt.hash, model: run.value}),
        pretty: true
      )
    )
  end

  defp fail(prefix, reason) do
    IO.puts(:stderr, "#{prefix}: #{inspect(reason)}")
    System.halt(1)
  end

  # Faithful JSON projection for the health/verify/ferroplan commands (keeps nil/booleans).
  @doc false
  def to_json(%Ex4pm.Refusal{} = refusal), do: refusal |> Map.from_struct() |> to_json()
  def to_json(%_{} = struct), do: struct |> Map.from_struct() |> to_json()

  def to_json(map) when is_map(map),
    do: Map.new(map, fn {k, v} -> {inspect_key(k), to_json(v)} end)

  def to_json(list) when is_list(list), do: Enum.map(list, &to_json/1)
  def to_json(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> Enum.map(&to_json/1)
  def to_json(value) when value in [nil, true, false], do: value
  def to_json(value) when is_atom(value), do: Atom.to_string(value)
  def to_json(value), do: value

  defp json_safe(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {inspect_key(key), json_safe(value)} end)
  end

  defp json_safe(list) when is_list(list), do: Enum.map(list, &json_safe/1)

  defp json_safe(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&json_safe/1)

  defp json_safe(value) when is_atom(value), do: Atom.to_string(value)
  defp json_safe(value), do: value

  defp inspect_key(key) when is_binary(key), do: key
  defp inspect_key(key) when is_atom(key), do: Atom.to_string(key)
  defp inspect_key(key), do: inspect(key)

  defp help(status) do
    IO.puts("""
    ex4pm - BEAM-native process intelligence

    usage:
      ex4pm doctor
      ex4pm contracts
      ex4pm discover <ocel-v2.json> [object-type]
      ex4pm discover-xes <log.xes> [case-object-type]
      ex4pm health
      ex4pm wasm verify
      ex4pm ferroplan version
      ex4pm ferroplan readiness
      ex4pm ferroplan plan <domain.pddl> <problem.pddl>
      ex4pm forecast '<json array | {"series": [...], "method": "forecast|holt|ewma", "alpha": n, "beta": n}>'
    """)

    if status != 0, do: System.halt(status)
  end
end
