defmodule Ex4pm.Information do
  @moduledoc """
  Reactor-first information plane for ex4pm.

  Non-trivial requests execute through an admitted Reactor graph. The only
  direct fast path is bounded, read-only introspection of the capability
  manifest itself.
  """

  alias Ex4pm.Core.Hash
  alias Ex4pm.Information.{Protocol, Registry}

  @protocol "ex4pm.information/1"
  @release "26.8.22"
  @max_json_bytes 33_554_432

  def protocol, do: @protocol
  def release, do: @release

  def manifest do
    %{
      protocol: @protocol,
      release: @release,
      architecture: %{
        canonical_semantics: :ex4pm_core,
        execution_plane: :reactor,
        do_authority: Ex4pm.Evidence.BRCE,
        direct_fast_path: [:manifest, :list, :describe],
        invariant:
          "parse -> route -> admit/refuse -> construct -> BRCE -> DO -> receipt -> replay -> standing"
      },
      capabilities: Registry.public_capabilities(),
      candidate_capabilities: Registry.candidate_capabilities(),
      transports: Registry.transport_graph()
    }
  end

  def list do
    Registry.public_capabilities()
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end

  def describe(capability) when is_binary(capability), do: Registry.describe(capability)

  def describe(other) do
    {:error,
     Ex4pm.Refusal.new(:invalid_capability_id, "capability id must be a string", subject: other)}
  end

  def execute(request, opts \\ [])

  def execute(request, opts) when is_map(request) do
    run_id = Hash.digest(%{information_request: request})
    {timeout, max_concurrency, async?} = Protocol.scheduler_limits(request, opts)

    reactor_opts = [
      run_id: run_id,
      timeout: timeout,
      max_concurrency: max_concurrency,
      async?: async?
    ]

    case Reactor.run(
           Ex4pm.Information.Flow,
           %{request: request},
           %{information_run_id: run_id},
           reactor_opts
         ) do
      {:ok, response} ->
        {:ok, response}

      {:ok, response, _reactor} ->
        {:ok, response}

      {:error, %Ex4pm.Refusal{} = refusal} ->
        {:ok, Protocol.refusal_response(request, refusal)}

      {:error, reason} ->
        case find_refusal(reason) do
          {:ok, refusal} -> {:ok, Protocol.refusal_response(request, refusal)}
          :error -> {:ok, Protocol.error_response(request, reason)}
        end

      {:halted, reactor} ->
        {:ok, Protocol.error_response(request, {:reactor_halted, inspect(reactor, limit: 5)})}
    end
  end

  def execute(other, _opts) do
    {:ok,
     Protocol.refusal_response(
       other,
       Ex4pm.Refusal.new(:invalid_request, "information request must be a map", subject: other)
     )}
  end

  def dispatch_json(bytes, opts \\ []) when is_binary(bytes) do
    if byte_size(bytes) > @max_json_bytes do
      response =
        Protocol.refusal_response(
          %{},
          Ex4pm.Refusal.new(:request_too_large, "JSON request exceeds the admitted byte bound",
            details: %{bytes: byte_size(bytes), maximum: @max_json_bytes}
          )
        )

      {:ok, Jason.encode!(Protocol.json_safe(response))}
    else
      with {:ok, request} <- Jason.decode(bytes),
           {:ok, response} <- execute(request, opts) do
        {:ok, Jason.encode!(Protocol.json_safe(response))}
      else
        {:error, %Jason.DecodeError{} = error} ->
          response =
            Protocol.refusal_response(
              %{},
              Ex4pm.Refusal.new(:invalid_json, "request is not valid JSON",
                details: %{message: Exception.message(error)}
              )
            )

          {:ok, Jason.encode!(Protocol.json_safe(response))}

        {:error, reason} ->
          {:ok, Jason.encode!(Protocol.error_response(%{}, reason))}
      end
    end
  end

  defp find_refusal(%Ex4pm.Refusal{} = refusal), do: {:ok, refusal}

  defp find_refusal(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> find_refusal()
  end

  defp find_refusal(map) when is_map(map) do
    Enum.reduce_while(map, :error, fn {key, value}, :error ->
      case find_refusal(key) do
        {:ok, refusal} ->
          {:halt, {:ok, refusal}}

        :error ->
          case find_refusal(value) do
            {:ok, refusal} -> {:halt, {:ok, refusal}}
            :error -> {:cont, :error}
          end
      end
    end)
  end

  defp find_refusal(list) when is_list(list) do
    Enum.reduce_while(list, :error, fn value, :error ->
      case find_refusal(value) do
        {:ok, refusal} -> {:halt, {:ok, refusal}}
        :error -> {:cont, :error}
      end
    end)
  end

  defp find_refusal(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> find_refusal()
  end

  defp find_refusal(_), do: :error
end
