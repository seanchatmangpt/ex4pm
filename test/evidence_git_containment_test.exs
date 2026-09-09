defmodule Ex4pm.Evidence.GitContainmentTest do
  use ExUnit.Case, async: true

  alias Ex4pm.Evidence.GitContainment

  setup do
    repo_dir =
      Path.join(System.tmp_dir!(), "ex4pm_git_containment_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(repo_dir)

    git!(repo_dir, ["init", "-q", "-b", "main"])
    git!(repo_dir, ["config", "user.email", "test@ex4pm.local"])
    git!(repo_dir, ["config", "user.name", "Ex4pm Test"])

    on_exit(fn -> File.rm_rf!(repo_dir) end)

    %{repo_dir: repo_dir}
  end

  defp git!(cwd, args) do
    case System.cmd("git", args, cd: cwd, stderr_to_stdout: true) do
      {output, 0} -> output
      {output, status} -> raise "git #{Enum.join(args, " ")} failed (#{status}): #{output}"
    end
  end

  defp commit!(repo_dir, filename, content) do
    File.write!(Path.join(repo_dir, filename), content)
    git!(repo_dir, ["add", filename])
    git!(repo_dir, ["commit", "-q", "-m", "commit #{filename}"])
    String.trim(git!(repo_dir, ["rev-parse", "HEAD"]))
  end

  test "ancestor?/2 returns true for a real ancestor commit", %{repo_dir: repo_dir} do
    first = commit!(repo_dir, "a.txt", "a")
    _second = commit!(repo_dir, "b.txt", "b")

    assert GitContainment.ancestor?(first, "main", cwd: repo_dir) == true
  end

  test "ancestor?/2 returns false for a commit on a divergent branch", %{repo_dir: repo_dir} do
    _base = commit!(repo_dir, "base.txt", "base")

    git!(repo_dir, ["checkout", "-q", "-b", "feature"])
    feature_commit = commit!(repo_dir, "feature.txt", "feature")

    git!(repo_dir, ["checkout", "-q", "main"])
    commit!(repo_dir, "main-only.txt", "main-only")

    assert GitContainment.ancestor?(feature_commit, "main", cwd: repo_dir) == false
  end

  test "ancestor?/2 raises a clear error for a real git error (unknown commit)", %{
    repo_dir: repo_dir
  } do
    commit!(repo_dir, "a.txt", "a")

    assert_raise RuntimeError, ~r/merge-base --is-ancestor/, fn ->
      GitContainment.ancestor?("deadbeefdeadbeefdeadbeefdeadbeefdeadbeef", "main", cwd: repo_dir)
    end
  end

  test "ahead_behind/2 returns the real correct ahead/behind counts for diverged branches", %{
    repo_dir: repo_dir
  } do
    commit!(repo_dir, "base.txt", "base")

    git!(repo_dir, ["branch", "diverged"])

    # 3 commits only on main
    commit!(repo_dir, "main1.txt", "1")
    commit!(repo_dir, "main2.txt", "2")
    commit!(repo_dir, "main3.txt", "3")

    # 2 commits only on diverged
    git!(repo_dir, ["checkout", "-q", "diverged"])
    commit!(repo_dir, "d1.txt", "1")
    commit!(repo_dir, "d2.txt", "2")

    result = GitContainment.ahead_behind("main", "diverged", cwd: repo_dir)

    assert result == %{ahead: 2, behind: 3}
  end

  test "containment_receipt/3 reports contained: true for a real fully-contained scenario", %{
    repo_dir: repo_dir
  } do
    base = commit!(repo_dir, "base.txt", "base")
    qualified_head = commit!(repo_dir, "q.txt", "q")
    commit!(repo_dir, "final.txt", "final")

    receipt = GitContainment.containment_receipt(base, qualified_head, "main", cwd: repo_dir)

    assert receipt.base == base
    assert receipt.qualified_head == qualified_head
    assert receipt.final_ref == "main"
    assert receipt.qualified_head_ancestor == true
    assert receipt.ahead_behind.behind == 0
    assert receipt.contained == true
  end

  test "containment_receipt/3 reports contained: false for a real not-contained scenario", %{
    repo_dir: repo_dir
  } do
    base = commit!(repo_dir, "base.txt", "base")

    git!(repo_dir, ["checkout", "-q", "-b", "qualified-branch"])
    qualified_head = commit!(repo_dir, "q.txt", "q")

    git!(repo_dir, ["checkout", "-q", "main"])
    commit!(repo_dir, "main-only.txt", "main-only")

    receipt =
      GitContainment.containment_receipt(base, qualified_head, "main", cwd: repo_dir)

    assert receipt.qualified_head_ancestor == false
    assert receipt.ahead_behind.behind > 0
    assert receipt.contained == false
  end
end
