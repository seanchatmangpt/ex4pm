defmodule Ex4pm.Qualification.Crown do
  @moduledoc "Manufactures the detached final crown only from independently verifiable evidence."

  alias Ex4pm.Qualification.Verifier

  def finalize(crown) do
    case Verifier.verify(crown) do
      {:ok, verified} ->
        crown
        |> Map.put("standing", "ALIVE")
        |> Map.put("verifier_identity", inspect(Verifier))
        |> Map.put("evidence_hash", verified.evidence_hash)
        |> then(&{:ok, &1})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def finalize_file(input, output) do
    with {:ok, bytes} <- File.read(input),
         {:ok, crown} <- Jason.decode(bytes),
         {:ok, finalized} <- finalize(crown),
         :ok <- File.mkdir_p(Path.dirname(output)),
         :ok <- File.write(output, Jason.encode!(finalized, pretty: true)) do
      {:ok, finalized}
    end
  end
end
