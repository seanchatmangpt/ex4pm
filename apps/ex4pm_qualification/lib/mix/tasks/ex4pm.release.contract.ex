defmodule Mix.Tasks.Ex4pm.Release.Contract do
  use Mix.Task
  @shortdoc "Manufacture the v26.8.23 executable release contract"

  def run(args) do
    Mix.Task.run("compile")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [evidence: :string, output: :string, require_alive: :boolean]
      )

    evidence = load_evidence(opts[:evidence] || System.get_env("EX4PM_RELEASE_EVIDENCE_JSON"))
    contract = Ex4pm.Qualification.ReleaseContract.evaluate(evidence)

    manifest =
      contract
      |> Map.put(:source_sha, subject_sha())
      |> Map.put(:tree_sha, subject_tree())

    output =
      opts[:output] ||
        "artifacts/qualification/release-contract-v#{Ex4pm.Qualification.ReleaseContract.version()}.json"

    File.mkdir_p!(Path.dirname(output))
    File.write!(output, Jason.encode!(manifest, pretty: true) <> "\n")

    Mix.shell().info(
      "ReleaseContract=#{String.upcase(to_string(contract.standing))} version=#{contract.version} output=#{output}"
    )

    if opts[:require_alive] and contract.standing != :alive do
      Mix.raise("release contract is not ALIVE: missing=#{inspect(contract.missing)} blocked=#{inspect(contract.blocked)}")
    end
  end

  defp load_evidence(nil), do: %{}

  defp load_evidence(path) do
    path
    |> File.read!()
    |> Jason.decode!()
  end

  defp subject_sha,
    do: System.get_env("EX4PM_SUBJECT_SHA") || git!("HEAD")

  defp subject_tree,
    do: System.get_env("EX4PM_SUBJECT_TREE") || git!("HEAD^{tree}")

  defp git!(rev) do
    case System.cmd("git", ["rev-parse", rev], stderr_to_stdout: true) do
      {value, 0} -> String.trim(value)
      {error, status} -> Mix.raise("cannot resolve #{rev}: exit=#{status} #{error}")
    end
  end
end
