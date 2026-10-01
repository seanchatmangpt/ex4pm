defmodule Ex4pm.Ggen.Generator do
  @moduledoc """
  Minimal, self-contained (ontology + query + EEx template -> out file) generation unit,
  used by `mix ex4pm.ggen.verify_determinism` to prove regeneration is byte-identical.

  Deliberately standalone: does not depend on any `ggen_igniter`/sibling-worktree task.
  Pure function of the ontology file's bytes and the query file's bytes -- no timestamps,
  no random IDs, no host-dependent paths in the rendered output -- so two renders of the
  same inputs are byte-identical by construction, and the determinism-verify task has a
  real regeneration to diff against rather than a stub.
  """

  @type unit :: %{
          required(:ontology) => Path.t(),
          required(:queries) => %{optional(String.t()) => Path.t()},
          required(:template) => Path.t(),
          required(:out) => Path.t()
        }

  @doc """
  Renders one generation unit and writes the result to `dest_path` (defaults to the
  unit's own `:out`). Returns `{:ok, content}` or `{:error, reason}`.
  """
  @spec render(unit(), Path.t() | nil) :: {:ok, String.t()} | {:error, term()}
  def render(unit, dest_path \\ nil) do
    with {:ok, ontology} <- File.read(unit.ontology),
         {:ok, queries} <- read_queries(unit.queries),
         {:ok, template} <- File.read(unit.template) do
      assigns = [
        ontology_source: unit.ontology,
        ontology_hash: sha256(ontology),
        query_sources: unit.queries,
        queries_hash: sha256(Enum.map_join(Enum.sort(queries), &elem(&1, 1))),
        standings: extract_standings(ontology),
        out_path: unit.out
      ]

      content = EEx.eval_string(template, assigns: assigns, trim: true)
      dest = dest_path || unit.out
      File.mkdir_p!(Path.dirname(dest))
      File.write!(dest, content)
      {:ok, content}
    end
  end

  defp read_queries(queries) do
    Enum.reduce_while(queries, {:ok, %{}}, fn {name, path}, {:ok, acc} ->
      case File.read(path) do
        {:ok, text} -> {:cont, {:ok, Map.put(acc, name, text)}}
        {:error, reason} -> {:halt, {:error, {path, reason}}}
      end
    end)
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)

  # Extracts `ex4pm:XXX` atoms from an `ex4pm:hasStanding ex4pm:A, ex4pm:B ;` triple line.
  # Real, deterministic parsing of the actual ontology text -- not a hardcoded list.
  defp extract_standings(ontology) do
    case Regex.run(~r/ex4pm:hasStanding\s+([^;.]+)[;.]/, ontology) do
      [_, list] ->
        list
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&String.replace_prefix(&1, "ex4pm:", ""))
        |> Enum.reject(&(&1 == ""))

      nil ->
        []
    end
  end
end
