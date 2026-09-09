defmodule Ex4pm.Information.Protocol do
  @moduledoc """
  Versioned deterministic request/response protocol for the ex4pm information plane.

  Protocol input is data only. It never creates atoms, modules, functions, or
  execution authority from external strings.
  """

  alias Ex4pm.Core.Hash
  alias Ex4pm.Refusal

  @protocol "ex4pm.information/1"
  @release "26.8.22"
  @allowed_keys ~w(protocol version request_id capability input context options limits)
  @default_timeout 30_000
  @max_timeout 120_000
  @default_concurrency 4
  @max_concurrency 64

  def normalize(request) when is_map(request) do
    with :ok <- reject_unknown_keys(request),
         {:ok, protocol} <- protocol_value(request),
         {:ok, version} <- version_value(request),
         {:ok, capability} <- required_binary(request, "capability"),
         {:ok, input} <- map_value(request, "input", %{}),
         {:ok, context} <- map_value(request, "context", %{}),
         {:ok, options} <- map_value(request, "options", %{}),
         {:ok, limits} <- normalize_limits(value(request, "limits", %{})),
         {:ok, request_id} <- request_id(request) do
      hash_subject = %{
        protocol: protocol,
        version: version,
        capability: capability,
        input: input,
        context: context,
        options: options,
        limits: limits
      }

      request_hash = Hash.digest(hash_subject)

      {:ok,
       %{
         protocol: protocol,
         version: version,
         request_id: request_id || request_hash,
         request_hash: request_hash,
         capability: capability,
         input: input,
         context: context,
         options: options,
         limits: limits
       }}
    end
  end

  def normalize(other) do
    {:error, Refusal.new(:invalid_request, "information request must be a map", subject: other)}
  end

  def scheduler_limits(request, opts) do
    requested =
      if is_map(request) do
        case value(request, "limits", %{}) do
          limits when is_map(limits) -> limits
          _ -> %{}
        end
      else
        %{}
      end

    timeout =
      opts
      |> Keyword.get(:timeout, value(requested, "timeout_ms", @default_timeout))
      |> bounded_integer(@default_timeout, 1, @max_timeout)

    max_concurrency =
      opts
      |> Keyword.get(
        :max_concurrency,
        value(requested, "max_concurrency", @default_concurrency)
      )
      |> bounded_integer(@default_concurrency, 1, @max_concurrency)

    async? =
      case Keyword.get(opts, :async?, value(requested, "async", true)) do
        value when is_boolean(value) -> value
        _ -> true
      end

    {timeout, max_concurrency, async?}
  end

  def response(admitted, execution, pending, outcome) do
    base = %{
      protocol: @protocol,
      version: @release,
      request_id: admitted.request_id,
      request_hash: admitted.request_hash,
      capability: admitted.capability,
      status: execution.status,
      standing: execution.standing,
      receipts: %{
        information_pending: pending.hash,
        information: outcome.hash,
        underlying: execution.underlying_receipts
      },
      provenance:
        Map.merge(
          %{
            reactor: "Ex4pm.Information.Flow",
            handler: admitted.handler,
            subject_hash: admitted.request_hash,
            result_hash: outcome.artifact_hash,
            authority_domain: "OBSERVE"
          },
          execution.provenance
        )
    }

    case execution.status do
      :ok ->
        Map.put(base, :result, execution.value)

      :refused ->
        Map.put(base, :refusal, refusal_map(execution.refusal))

      :error ->
        Map.put(base, :error, error_map(execution.error))
    end
  end

  def refusal_response(request, %Refusal{} = refusal) do
    identity = partial_identity(request)

    %{
      protocol: @protocol,
      version: @release,
      request_id: identity.request_id,
      request_hash: identity.request_hash,
      capability: identity.capability,
      status: :refused,
      standing: :unknown,
      receipts: %{information_pending: nil, information: nil, underlying: []},
      refusal: refusal_map(refusal),
      provenance: %{
        reactor: "Ex4pm.Information.Flow",
        admitted: false,
        actuated: false,
        authority_domain: "OBSERVE"
      }
    }
  end

  def error_response(request, reason) do
    identity = partial_identity(request)

    %{
      protocol: @protocol,
      version: @release,
      request_id: identity.request_id,
      request_hash: identity.request_hash,
      capability: identity.capability,
      status: :error,
      standing: :unknown,
      receipts: %{information_pending: nil, information: nil, underlying: []},
      error: error_map(reason),
      provenance: %{
        reactor: "Ex4pm.Information.Flow",
        admitted: false,
        actuated: false,
        authority_domain: "OBSERVE"
      }
    }
  end

  def refusal_map(%Refusal{} = refusal) do
    %{
      code: refusal.code,
      message: refusal.message,
      details: json_safe(refusal.details)
    }
  end

  def json_safe(%Refusal{} = refusal), do: refusal_map(refusal)
  def json_safe(%MapSet{} = set), do: set |> MapSet.to_list() |> Enum.map(&json_safe/1)
  def json_safe(%DateTime{} = value), do: DateTime.to_iso8601(value)
  def json_safe(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  def json_safe(%Date{} = value), do: Date.to_iso8601(value)
  def json_safe(%Time{} = value), do: Time.to_iso8601(value)

  def json_safe(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> json_safe()
  end

  def json_safe(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {json_key(key), json_safe(value)} end)
  end

  def json_safe(list) when is_list(list), do: Enum.map(list, &json_safe/1)

  def json_safe(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&json_safe/1)

  def json_safe(value) when is_atom(value), do: Atom.to_string(value)
  def json_safe(value) when is_reference(value), do: inspect(value)
  def json_safe(value) when is_pid(value), do: inspect(value)
  def json_safe(value) when is_function(value), do: inspect(value)
  def json_safe(value), do: value

  defp protocol_value(request) do
    case value(request, "protocol", @protocol) do
      @protocol ->
        {:ok, @protocol}

      other ->
        {:error,
         Refusal.new(:unsupported_protocol, "unsupported information protocol",
           details: %{expected: @protocol, actual: other}
         )}
    end
  end

  defp version_value(request) do
    case value(request, "version", @release) do
      @release ->
        {:ok, @release}

      other ->
        {:error,
         Refusal.new(:unsupported_protocol_version, "unsupported information protocol version",
           details: %{expected: @release, actual: other}
         )}
    end
  end

  defp request_id(request) do
    case value(request, "request_id") do
      nil ->
        {:ok, nil}

      id when is_binary(id) and byte_size(id) > 0 and byte_size(id) <= 256 ->
        {:ok, id}

      other ->
        {:error,
         Refusal.new(:invalid_request_id, "request_id must be a non-empty string", subject: other)}
    end
  end

  defp required_binary(map, key) do
    case value(map, key) do
      value when is_binary(value) and byte_size(value) > 0 ->
        {:ok, value}

      other ->
        {:error,
         Refusal.new(:invalid_protocol_field, "#{key} must be a non-empty string", subject: other)}
    end
  end

  defp map_value(map, key, default) do
    case value(map, key, default) do
      value when is_map(value) ->
        {:ok, value}

      other ->
        {:error, Refusal.new(:invalid_protocol_field, "#{key} must be an object", subject: other)}
    end
  end

  defp normalize_limits(limits) when is_map(limits) do
    allowed = ~w(timeout_ms max_concurrency async)
    unknown = unknown_keys(limits, allowed)

    if unknown != [] do
      {:error,
       Refusal.new(:unknown_limit, "request contains unsupported execution limits",
         details: %{unknown: unknown, allowed: allowed}
       )}
    else
      timeout = value(limits, "timeout_ms", @default_timeout)
      concurrency = value(limits, "max_concurrency", @default_concurrency)
      async? = value(limits, "async", true)

      cond do
        not (is_integer(timeout) and timeout > 0 and timeout <= @max_timeout) ->
          {:error,
           Refusal.new(:invalid_timeout, "timeout_ms is outside the admitted bound",
             details: %{minimum: 1, maximum: @max_timeout, actual: timeout}
           )}

        not (is_integer(concurrency) and concurrency > 0 and concurrency <= @max_concurrency) ->
          {:error,
           Refusal.new(:invalid_concurrency, "max_concurrency is outside the admitted bound",
             details: %{minimum: 1, maximum: @max_concurrency, actual: concurrency}
           )}

        not is_boolean(async?) ->
          {:error, Refusal.new(:invalid_async_flag, "async must be boolean", subject: async?)}

        true ->
          {:ok, %{timeout_ms: timeout, max_concurrency: concurrency, async: async?}}
      end
    end
  end

  defp normalize_limits(other) do
    {:error, Refusal.new(:invalid_limits, "limits must be an object", subject: other)}
  end

  defp reject_unknown_keys(request) do
    case unknown_keys(request, @allowed_keys) do
      [] ->
        :ok

      unknown ->
        {:error,
         Refusal.new(:unknown_protocol_field, "request contains unsupported top-level fields",
           details: %{unknown: unknown, allowed: @allowed_keys}
         )}
    end
  end

  defp unknown_keys(map, allowed) do
    map
    |> Map.keys()
    |> Enum.map(&key_string/1)
    |> Enum.reject(&(&1 in allowed))
    |> Enum.sort()
  end

  defp partial_identity(request) when is_map(request) do
    capability =
      case value(request, "capability") do
        value when is_binary(value) -> value
        _ -> nil
      end

    request_id =
      case value(request, "request_id") do
        value when is_binary(value) -> value
        _ -> nil
      end

    %{
      request_id: request_id,
      request_hash: Hash.digest(%{raw_request: request}),
      capability: capability
    }
  end

  defp partial_identity(other) do
    %{request_id: nil, request_hash: Hash.digest(%{raw_request: other}), capability: nil}
  end

  defp error_map(%Refusal{} = refusal), do: %{kind: :refusal, refusal: refusal_map(refusal)}

  defp error_map(reason) do
    %{kind: :runtime_error, detail: inspect(reason, limit: 20, printable_limit: 2_000)}
  end

  defp bounded_integer(value, _default, minimum, maximum)
       when is_integer(value) and value >= minimum and value <= maximum,
       do: value

  defp bounded_integer(_value, default, _minimum, _maximum), do: default

  defp value(map, key, default \\ nil) when is_map(map) and is_binary(key) do
    case Map.fetch(map, key) do
      {:ok, value} ->
        value

      :error ->
        atom_key =
          case key do
            "protocol" -> :protocol
            "version" -> :version
            "request_id" -> :request_id
            "capability" -> :capability
            "input" -> :input
            "context" -> :context
            "options" -> :options
            "limits" -> :limits
            "timeout_ms" -> :timeout_ms
            "max_concurrency" -> :max_concurrency
            "async" -> :async
            _ -> nil
          end

        if atom_key && Map.has_key?(map, atom_key), do: Map.fetch!(map, atom_key), else: default
    end
  end

  defp key_string(key) when is_binary(key), do: key
  defp key_string(key) when is_atom(key), do: Atom.to_string(key)
  defp key_string(key), do: inspect(key)

  defp json_key(key) when is_binary(key), do: key
  defp json_key(key) when is_atom(key), do: Atom.to_string(key)
  defp json_key(key), do: inspect(key)
end
