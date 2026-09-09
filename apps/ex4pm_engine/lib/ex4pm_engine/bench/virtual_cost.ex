defmodule Ex4pmEngine.Bench.VirtualCost do
  @moduledoc """
  Real virtual-cost counter for distributed-engine topology benchmarks.

  Tracks Hardware-Interaction-Instructions-style operation counts —
  `:compute`, `:store`, `:send` — as plain non-negative integers. This is not
  a wall-clock timer: it is an explicit, real, incrementable counter that
  benchmark code calls at each real operation site (one increment per real
  local computation step, one per real write to an accumulator/store, one per
  real inter-process message sent), so the resulting totals reflect actual
  operations performed during a real run, not an estimate.
  """

  @enforce_keys [:compute, :store, :send]
  defstruct [:compute, :store, :send]

  @type t :: %__MODULE__{
          compute: non_neg_integer(),
          store: non_neg_integer(),
          send: non_neg_integer()
        }

  @doc "A fresh zeroed counter."
  @spec new() :: t()
  def new, do: %__MODULE__{compute: 0, store: 0, send: 0}

  @doc "Increment the :compute counter by `n` (default 1)."
  @spec compute(t(), pos_integer()) :: t()
  def compute(%__MODULE__{} = c, n \\ 1) when is_integer(n) and n > 0 do
    %__MODULE__{c | compute: c.compute + n}
  end

  @doc "Increment the :store counter by `n` (default 1)."
  @spec store(t(), pos_integer()) :: t()
  def store(%__MODULE__{} = c, n \\ 1) when is_integer(n) and n > 0 do
    %__MODULE__{c | store: c.store + n}
  end

  @doc "Increment the :send counter by `n` (default 1)."
  @spec send_op(t(), pos_integer()) :: t()
  def send_op(%__MODULE__{} = c, n \\ 1) when is_integer(n) and n > 0 do
    %__MODULE__{c | send: c.send + n}
  end

  @doc "Merge two counters by summing each field. Used to combine per-process counters."
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = a, %__MODULE__{} = b) do
    %__MODULE__{compute: a.compute + b.compute, store: a.store + b.store, send: a.send + b.send}
  end

  @doc "Sum a list of counters into one total."
  @spec sum([t()]) :: t()
  def sum(counters) when is_list(counters), do: Enum.reduce(counters, new(), &merge(&2, &1))

  @doc "Total operation count across all three dimensions."
  @spec total(t()) :: non_neg_integer()
  def total(%__MODULE__{compute: c, store: s, send: sd}), do: c + s + sd
end
