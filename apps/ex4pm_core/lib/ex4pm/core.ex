defmodule Ex4pm.Standing do
  @moduledoc "Bounded evidence standing shared with wasm4pm semantics."

  @statuses [:unknown, :partial_alive, :alive, :blocked, :build_broken, :unsupported]

  @type t :: :unknown | :partial_alive | :alive | :blocked | :build_broken | :unsupported

  def all, do: @statuses
  def valid?(status), do: status in @statuses

  def rank(:unknown), do: 0
  def rank(:unsupported), do: 1
  def rank(:build_broken), do: 2
  def rank(:blocked), do: 3
  def rank(:partial_alive), do: 4
  def rank(:alive), do: 5
  def rank(_), do: -1

  def min(left, right) do
    if rank(left) <= rank(right), do: left, else: right
  end
end

defmodule Ex4pm.Refusal do
  @moduledoc "Typed admission refusal. Refusal is not runtime failure."

  @enforce_keys [:code, :message]
  defstruct [:code, :message, :subject, details: %{}]

  @type t :: %__MODULE__{
          code: atom(),
          message: String.t(),
          subject: term(),
          details: map()
        }

  def new(code, message, opts \\ []) do
    %__MODULE__{
      code: code,
      message: message,
      subject: Keyword.get(opts, :subject),
      details: Map.new(Keyword.get(opts, :details, %{}))
    }
  end
end

defmodule Ex4pm.Subject do
  @moduledoc "Immutable identity carrier for an admitted subject."

  @enforce_keys [:kind, :hash]
  defstruct [:kind, :hash, metadata: %{}]

  def new(kind, value, metadata \\ %{}) do
    %__MODULE__{kind: kind, hash: Ex4pm.Core.Hash.digest(value), metadata: metadata}
  end
end

defmodule Ex4pm.Core.Hash do
  @moduledoc "Deterministic content hashing with explicit algorithm identity."

  @type digest :: String.t()

  def digest(term, algorithm \\ :sha256)

  def digest(term, :sha256) do
    bytes = :erlang.term_to_binary(canonical(term), [:deterministic])
    "sha256:" <> Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
  end

  def digest(term, {:provider, module, algorithm}) when is_atom(module) do
    if function_exported?(module, :digest, 2) do
      case module.digest(canonical(term), algorithm) do
        {:ok, digest} when is_binary(digest) -> digest
        digest when is_binary(digest) -> digest
        other -> {:error, {:invalid_hash_provider_result, other}}
      end
    else
      {:error, {:unsupported_hash_provider, module}}
    end
  end

  def digest(_term, algorithm), do: {:error, {:unsupported_hash_algorithm, algorithm}}

  def canonical(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> canonical()
  end

  def canonical(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {canonical(key), canonical(value)} end)
    |> Enum.sort_by(fn {key, _value} -> :erlang.term_to_binary(key, [:deterministic]) end)
  end

  def canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)
  def canonical(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> Enum.map(&canonical/1) |> List.to_tuple()
  def canonical(value), do: value
end

defmodule Ex4pm.Core.Capability do
  @moduledoc "One admitted capability edge in the DfCM graph."

  @enforce_keys [:id, :kind, :standing]
  defstruct [:id, :kind, :standing, :reason, evidence: %{}, constraints: %{}]
end

defmodule Ex4pm.Core.CapabilityGraph do
  @moduledoc "Preserves all lawful candidates before selection."

  alias Ex4pm.Core.Capability

  def new(capabilities \\ []) do
    capabilities
    |> Enum.map(fn
      %Capability{} = capability -> capability
      map when is_map(map) -> struct!(Capability, map)
    end)
    |> Map.new(&{&1.id, &1})
  end

  def put(graph, %Capability{id: id} = capability), do: Map.put(graph, id, capability)
  def get(graph, id), do: Map.get(graph, id)

  def candidates(graph, kind) do
    graph
    |> Map.values()
    |> Enum.filter(&(&1.kind == kind))
    |> Enum.sort_by(fn capability -> {-Ex4pm.Standing.rank(capability.standing), capability.id} end)
  end

  def best(graph, kind) do
    case candidates(graph, kind) do
      [candidate | _] -> {:ok, candidate}
      [] -> {:error, Ex4pm.Refusal.new(:no_candidate, "no lawful capability candidate", details: %{kind: kind})}
    end
  end
end
