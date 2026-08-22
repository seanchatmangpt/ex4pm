defmodule Ex4pm.CLI do
  @moduledoc """
  Human and machine CLI projection over `Ex4pm.Information`.

  `manifest`, `list`, and `describe` are bounded read-only introspection.
  Every non-trivial command is converted to the versioned information protocol
  and executed through Reactor.
  """

  alias Ex4pm.Information
  alias Ex4pm.Information.Protocol

  def main(args) do
    case args do
      ["manifest"] ->
        print_json(Information.manifest(), pretty: true)

      ["list"] ->
        print_json(%{protocol: Information.protocol(), capabilities: Information.list()},
          pretty: true
        )

      ["describe", capability] ->
        describe(capability)

      ["run", capability] ->
        run(capability, "{}")

      ["run", capability, json] ->
        run(capability, json)

      ["stdio"] ->
        stdio()

      ["doctor"] ->
        execute(%{"capability" => "system.doctor"})

      ["contracts"] ->
        execute(%{"capability" => "system.contracts"})

      ["discover", path] ->
        execute(%{
          "capability" => "process.discover_file",
          "input" => %{"path" => path}
        })

      ["discover", path, object_type] ->
        execute(%{
          "capability" => "process.discover_file",
          "input" => %{"path" => path, "object_type" => object_type}
        })

      ["discover-xes", path] ->
        execute(%{
          "capability" => "process.discover_xes_file",
          "input" => %{"path" => path}
        })

      ["discover-xes", path, case_object_type] ->
        execute(%{
          "capability" => "process.discover_xes_file",
          "input" => %{"path" => path, "case_object_type" => case_object_type}
        })

      ["help"] ->
        help(0)

      [] ->
        help(0)

      _ ->
        help(2)
    end
  end

  defp describe(capability) do
    case Information.describe(capability) do
      {:ok, description} ->
        print_json(description, pretty: true)

      {:error, refusal} ->
        print_json(Protocol.refusal_response(%{"capability" => capability}, refusal),
          pretty: true
        )
    end
  end

  defp run(capability, source) do
    with {:ok, bytes} <- request_bytes(source),
         {:ok, fragment} <- Jason.decode(bytes),
         true <- is_map(fragment) do
      fragment
      |> Map.put("capability", capability)
      |> execute()
    else
      false ->
        execute(%{
          "capability" => capability,
          "input" => %{"invalid_fragment" => "run request must be a JSON object"}
        })

      {:error, reason} ->
        print_json(
          Protocol.error_response(
            %{"capability" => capability},
            {:cli_request_decode_failed, reason}
          ),
          pretty: true
        )
    end
  end

  defp execute(request) do
    request =
      request
      |> Map.put_new("protocol", Information.protocol())
      |> Map.put_new("version", Information.release())

    case Information.execute(request) do
      {:ok, response} -> print_json(response, pretty: true)
    end
  end

  defp stdio do
    IO.stream(:stdio, :line)
    |> Enum.each(fn line ->
      if String.trim(line) != "" do
        case Information.dispatch_json(line) do
          {:ok, encoded} -> IO.puts(encoded)
        end
      end
    end)
  end

  defp request_bytes("-"), do: {:ok, IO.read(:stdio, :eof)}
  defp request_bytes(json), do: {:ok, json}

  defp print_json(value, opts) do
    pretty? = Keyword.get(opts, :pretty, false)

    IO.puts(
      Jason.encode!(Protocol.json_safe(value),
        pretty: pretty?
      )
    )
  end

  defp help(status) do
    IO.puts("""
    ex4pm - Reactor-first BEAM process intelligence

    direct introspection (no execution receipt):
      ex4pm manifest
      ex4pm list
      ex4pm describe <capability>

    Reactor information plane:
      ex4pm run <capability> '<request-fragment-json>'
      ex4pm run <capability> -
      ex4pm stdio

    compatibility projections (also Reactor-backed):
      ex4pm doctor
      ex4pm contracts
      ex4pm discover <ocel-v2.json> [object-type]
      ex4pm discover-xes <log.xes> [case-object-type]

    protocol:
      #{Information.protocol()} release #{Information.release()}
    """)

    if status != 0, do: System.halt(status)
  end
end
