defmodule Mix.Tasks.Ex4pm.Rails.Court do
  use Mix.Task
  @shortdoc "Execute the exact v26.8.23 five-rail reference court"

  def run(args) do
    Mix.Task.run("compile")
    output = List.first(args) || "artifacts/qualification/rails"

    case Ex4pm.Qualification.ReferenceRailCourt.run(output) do
      {:ok, manifest} ->
        Mix.shell().info(
          "ReferenceRails=#{manifest.standing} rails=#{manifest.rails |> Enum.map(& &1.engine) |> Enum.join(",")}" 
        )

      {:error, reason} ->
        Mix.raise("reference rail court failed: #{inspect(reason)}")
    end
  end
end
