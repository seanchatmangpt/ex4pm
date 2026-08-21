defmodule Ex4pm.CLI do
  @moduledoc "Minimal CLI projection over the canonical ex4pm API."

  def main(args) do
    case args do
      ["doctor"] -> doctor()
      ["discover", path] -> discover(path, [])
      ["discover", path, object_type] -> discover(path, object_type: object_type)
      ["help"] -> help(0)
      [] -> help(0)
      _ -> help(2)
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

    IO.puts(Jason.encode!(%{operation: :discover, candidates: payload}, pretty: true))
  end

  defp discover(path, opts) do
    with {:ok, bytes} <- File.read(path),
         {:ok, raw} <- Jason.decode(bytes),
         {:ok, run} <- Ex4pm.discover(raw, opts) do
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
    else
      {:error, reason} ->
        IO.puts(:stderr, "ex4pm discover refused/failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp json_safe(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {inspect_key(key), json_safe(value)} end)
  end

  defp json_safe(list) when is_list(list), do: Enum.map(list, &json_safe/1)
  defp json_safe(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> Enum.map(&json_safe/1)
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
      ex4pm discover <ocel-v2.json> [object-type]
    """)

    if status != 0, do: System.halt(status)
  end
end
