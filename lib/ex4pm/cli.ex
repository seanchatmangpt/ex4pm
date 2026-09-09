defmodule Ex4pm.CLI do
  @moduledoc "CLI projection over the canonical ex4pm API."

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

    contract =
      case Ex4pm.contracts() do
        {:ok, verified} -> %{standing: verified.standing, hash: verified.contract_hash}
        {:error, refusal} -> %{standing: :blocked, refusal: inspect(refusal)}
      end

    IO.puts(
      Jason.encode!(%{operation: :discover, candidates: payload, contracts: contract},
        pretty: true
      )
    )
  end

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

  defp fail(prefix, reason) do
    IO.puts(:stderr, "#{prefix}: #{inspect(reason)}")
    System.halt(1)
  end

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
    """)

    if status != 0, do: System.halt(status)
  end
end
