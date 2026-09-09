defmodule Mix.Tasks.Ex4pm.Powl.Court do
  use Mix.Task
  @shortdoc "Run bounded and generated POWL/Reactor correspondence courts"

  def run(_args) do
    Mix.Task.run("compile")

    with {:ok, baseline} <- Ex4pm.Qualification.Powl.Correspondence.court(),
         {:ok, generated} <- Ex4pm.Qualification.Powl.PropertyCorpus.run(2_048),
         {:ok, invalid} <- Ex4pm.Qualification.Powl.PropertyCorpus.invalid_identity_court() do
      Mix.shell().info(
        "POWL correspondence ALIVE baseline=#{inspect(baseline, limit: 5)} " <>
          "generated=#{inspect(generated)} invalid=#{inspect(invalid)}"
      )
    else
      {:error, reason} -> Mix.raise("POWL correspondence failed: #{inspect(reason)}")
    end
  end
end

defmodule Mix.Tasks.Ex4pm.Sabotage.Court do
  use Mix.Task
  @shortdoc "Prove that POWL correspondence sabotage is detected"

  def run(_args) do
    Mix.Task.run("compile")
    alias Ex4pmEngine.POWL

    model =
      POWL.loop(
        "loop",
        POWL.sequence("seq", [POWL.activity("a", "A"), POWL.activity("b", "B")]),
        POWL.activity("r", "R")
      )

    mutations = [
      :extra_trace,
      :missing_trace,
      :wrong_order,
      :duplicate_execution,
      :lost_terminal,
      :wrong_bound
    ]

    survivors =
      Enum.reject(
        mutations,
        &(Ex4pm.Qualification.Powl.Correspondence.sabotage(model, 2, &1) == :detected)
      )

    if survivors == [] do
      Mix.shell().info("POWL sabotage court ALIVE")
    else
      Mix.raise("sabotage survived: #{inspect(survivors)}")
    end
  end
end

defmodule Mix.Tasks.Ex4pm.Crown do
  use Mix.Task
  @shortdoc "Verify and manufacture the detached v26.8.22 final crown receipt"

  def run(args) do
    Mix.Task.run("compile")

    input =
      List.first(args) || System.get_env("EX4PM_CROWN_INPUT") ||
        Mix.raise("crown evidence input required")

    output = Enum.at(args, 1) || "artifacts/qualification/ex4pm-final-crown-v1.json"

    case Ex4pm.Qualification.Crown.finalize_file(input, output) do
      {:ok, crown} ->
        Mix.shell().info(
          "RepositoryStanding=#{crown["standing"]} evidence=#{crown["evidence_hash"]}"
        )

      {:error, reason} ->
        Mix.raise("crown refused: #{inspect(reason)}")
    end
  end
end
