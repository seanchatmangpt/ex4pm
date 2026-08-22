defmodule Ex4pm.Standing do
  @moduledoc "Standing calculation and ranking semantics."

  @rank %{
    alive: 4,
    ALIVE: 4,
    partial_alive: 3,
    PARTIAL_ALIVE: 3,
    blocked: 2,
    BLOCKED: 2,
    build_broken: 1,
    BUILD_BROKEN: 1,
    unsupported: 0,
    UNSUPPORTED: 0,
    unknown: 0,
    UNKNOWN: 0
  }

  def rank(standing) when is_atom(standing) do
    Map.get(@rank, standing, 0)
  end

  def min(left, right) do
    if rank(left) <= rank(right), do: left, else: right
  end

  def to_string(standing), do: Atom.to_string(standing) |> String.upcase()
end

defmodule Ex4pm.Refusal do
  @moduledoc """
  Typed refusal struct representing formal domain refusals in ex4pm.
  """

  @enforce_keys [:code, :message]
  defstruct [:code, :message, :subject, details: %{}]

  @type t :: %__MODULE__{
          code: atom(),
          message: String.t(),
          subject: term() | nil,
          details: map()
        }

  def new(code, message, opts \\ []) do
    subject = Keyword.get(opts, :subject)
    details = Keyword.get(opts, :details, %{})
    %__MODULE__{code: code, message: message, subject: subject, details: details}
  end

  def exception(opts) do
    code = Keyword.get(opts, :code, :refusal)
    message = Keyword.get(opts, :message, "Operation refused")
    new(code, message, opts)
  end
end

defmodule Ex4pm.Subject do
  @moduledoc "Immutable identity carrier for an admitted subject."

  @enforce_keys [:kind, :hash]
  defstruct [:id, :kind, :hash, metadata: %{}]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          kind: atom(),
          hash: String.t(),
          metadata: map()
        }

  def new(kind, value, metadata \\ %{}) do
    %__MODULE__{kind: kind, hash: Ex4pm.Core.Hash.digest(value), metadata: metadata}
  end
end

defmodule Ex4pm.Core.Hash do
  @moduledoc "Deterministic content hashing with explicit algorithm identity."

  @type digest :: String.t()

  def digest(term, algorithm \\ :sha256)

  def digest(term, :sha256) do
    binary =
      cond do
        is_binary(term) -> term
        is_map(term) -> :erlang.term_to_binary(canonicalize(term))
        true -> :erlang.term_to_binary(term)
      end

    "sha256:" <> (:crypto.hash(:sha256, binary) |> Base.encode16(case: :lower))
  end

  defp canonicalize(term) when is_struct(term) do
    term |> Map.from_struct() |> canonicalize()
  end

  defp canonicalize(map) when is_map(map) do
    Enum.map(map, fn {k, v} -> {key_to_string(k), canonicalize(v)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp canonicalize(list) when is_list(list) do
    Enum.map(list, &canonicalize/1)
  end

  defp canonicalize(other), do: other

  defp key_to_string(k) when is_tuple(k),
    do: :erlang.term_to_binary(k) |> Base.encode16(case: :lower)

  defp key_to_string(k) when is_atom(k) or is_binary(k) or is_number(k), do: to_string(k)
  defp key_to_string(k), do: inspect(k)
end

defmodule Ex4pm.Core.Capability do
  @moduledoc "An engine capability descriptor."

  @enforce_keys [:id, :kind, :standing]
  defstruct [:id, :kind, :standing, :reason, evidence: %{}, constraints: %{}]

  @type t :: %__MODULE__{
          id: String.t() | atom(),
          kind: atom(),
          standing: atom(),
          reason: String.t() | nil,
          evidence: map(),
          constraints: map()
        }
end

defmodule Ex4pm.Claim do
  @moduledoc "A verified or pending claim in the process intelligence system."

  @enforce_keys [:id, :kind, :standing]
  defstruct [:id, :kind, :standing, :reason, evidence: %{}, constraints: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          kind: atom(),
          standing: atom(),
          reason: String.t() | nil,
          evidence: map(),
          constraints: map()
        }
end
