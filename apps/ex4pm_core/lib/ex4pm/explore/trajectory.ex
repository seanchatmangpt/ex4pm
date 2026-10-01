defmodule Ex4pm.Explore.Trajectory do
  @moduledoc false

  def differences(values) when is_list(values) do
    values |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [a, b] -> b - a end)
  end

  def second_differences(values), do: values |> differences() |> differences()

  def integral(values, dt \\ 1.0) do
    values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(0.0, fn [a, b], acc -> acc + (a + b) * 0.5 * dt end)
  end
end
