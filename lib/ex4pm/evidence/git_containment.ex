defmodule Ex4pm.Evidence.GitContainment do
  @moduledoc """
  Real `git` subprocess wrapper for ancestor/ahead-behind containment evidence.

  A small, real wrapper (subprocess-based, real `git` calls -- Chicago
  discipline, no libgit2 binding needed for this scope): `ancestor?/2` (is
  commit A an ancestor of ref B), `ahead_behind/2` (returns
  `%{ahead: n, behind: n}` for two refs, matching the "55 commits ahead, 0
  behind" shape every receipt reports), and `containment_receipt/3` (base,
  qualified_head, final_ref -- returns a receipted map combining both checks,
  directly usable as evidence in a caller's own standing computation).

  No algorithm is reimplemented here -- every call shells out to the real
  `git` binary and parses its real output. Classification: pat-wrapper-over-
  collaborator (matching beam4pm's own `BeamPM.Petgraph`/`Tract`/`Rust4pm`
  precedent).
  """

  @doc """
  Returns `true` if `commit` is a real ancestor of `ref`, `false` if it is
  not. Runs `git merge-base --is-ancestor <commit> <ref>` in `opts[:cwd]`
  (default `File.cwd!()`).

  Exit code `0` means ancestor (`true`); exit code `1` means not-an-ancestor
  (`false`) -- both are well-defined outcomes per `git-merge-base(1)`. Any
  other exit code (e.g. one of the refs does not exist) raises, since that is
  a real git error and must never be silently coerced to `false`.
  """
  @spec ancestor?(String.t(), String.t(), keyword()) :: boolean()
  def ancestor?(commit, ref, opts \\ []) do
    cwd = Keyword.get(opts, :cwd, File.cwd!())

    case System.cmd("git", ["merge-base", "--is-ancestor", commit, ref],
           cd: cwd,
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        true

      {_output, 1} ->
        false

      {output, status} ->
        raise "git merge-base --is-ancestor #{commit} #{ref} failed with exit #{status}: #{output}"
    end
  end

  @doc """
  Returns `%{ahead: n, behind: n}` for `base_ref...target_ref`, computed from
  a real `git rev-list --left-right --count <base_ref>...<target_ref>` call
  in `opts[:cwd]` (default `File.cwd!()`).

  Matches git's own `--left-right` semantics for `base...target`: the left
  (base-only) count is `behind`, the right (target-only) count is `ahead`.
  """
  @spec ahead_behind(String.t(), String.t(), keyword()) :: %{
          ahead: non_neg_integer(),
          behind: non_neg_integer()
        }
  def ahead_behind(base_ref, target_ref, opts \\ []) do
    cwd = Keyword.get(opts, :cwd, File.cwd!())
    range = "#{base_ref}...#{target_ref}"

    case System.cmd("git", ["rev-list", "--left-right", "--count", range], cd: cwd) do
      {output, 0} ->
        [behind_str, ahead_str] =
          output
          |> String.trim()
          |> String.split("\t")

        %{ahead: String.to_integer(ahead_str), behind: String.to_integer(behind_str)}

      {output, status} ->
        raise "git rev-list --left-right --count #{range} failed with exit #{status}: #{output}"
    end
  end

  @doc """
  Combines `ancestor?/2` and `ahead_behind/2` into one real evidence map,
  directly usable as evidence in a caller's own standing computation.

  `contained` is `true` iff `qualified_head` is a real ancestor of
  `final_ref` AND `ahead_behind(qualified_head, final_ref).behind == 0`
  (i.e. nothing on `qualified_head` is missing from `final_ref`).
  """
  @spec containment_receipt(String.t(), String.t(), String.t(), keyword()) :: map()
  def containment_receipt(base, qualified_head, final_ref, opts \\ []) do
    qualified_head_ancestor = ancestor?(qualified_head, final_ref, opts)
    ahead_behind_map = ahead_behind(qualified_head, final_ref, opts)

    %{
      base: base,
      qualified_head: qualified_head,
      final_ref: final_ref,
      qualified_head_ancestor: qualified_head_ancestor,
      ahead_behind: ahead_behind_map,
      contained: qualified_head_ancestor and ahead_behind_map.behind == 0
    }
  end
end
