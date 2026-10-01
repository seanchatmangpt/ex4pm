# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Ex4pm.Exposure.Court do
  @moduledoc """
  Exposure-completeness court (`Ex4pm.Qualification.ExposureCourt`).

      mix ex4pm.exposure.court                # static layers (adapter, engine op, public fn, doc, real test)
      mix ex4pm.exposure.court --require-real # also EXECUTE every algorithm + ferroplan core op for real

  Exits non-zero (typed `REFUSED_EXPOSURE_<LAYER>` per subject) on any violation
  outside the declared, non-growing known-gap list.
  """
  use Mix.Task

  alias Ex4pm.Qualification.ExposureCourt

  @shortdoc "Court: every wasm4pm algorithm / ferroplan op is exposed, documented, really tested"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [require_real: :boolean])
    require_real = Keyword.get(opts, :require_real, false)

    Mix.Task.run("compile")
    if require_real, do: Mix.Task.run("app.start")

    case ExposureCourt.run(require_real: require_real) do
      {:ok, receipt} ->
        shell = Mix.shell()
        s = receipt.subjects

        shell.info(
          "exposure court (#{receipt.mode}): subjects algorithms=#{s.algorithms} " <>
            "wasm_exports=#{s.wasm_exports} ferroplan_ops=#{s.ferroplan_ops}; " <>
            "executed=#{length(receipt.executed)}; known_gaps=#{length(receipt.known_gaps)}"
        )

        receipt.known_gaps
        |> Enum.group_by(& &1.broken_term)
        |> Enum.each(fn {term, vs} ->
          shell.info(
            "  KNOWN_GAP #{term} x#{length(vs)}: #{vs |> Enum.map(&subject_name/1) |> Enum.join(", ")}"
          )
        end)

        for {layer, matcher, owner} <- receipt.stale_known_gaps do
          shell.info(
            "  STALE known gap (close it in ExposureCourt @known_gaps): #{layer} #{inspect(matcher)} [#{owner}]"
          )
        end

      {:refused, violations} ->
        Enum.each(violations, fn x ->
          Mix.shell().error("  #{x.broken_term} #{subject_name(x)}: #{x.detail}")
        end)

        Mix.raise("exposure court REFUSED: #{length(violations)} violation(s)")
    end
  end

  defp subject_name({_kind, name}), do: to_string(name)
  defp subject_name(%{subject: {_kind, name}}), do: to_string(name)
end
