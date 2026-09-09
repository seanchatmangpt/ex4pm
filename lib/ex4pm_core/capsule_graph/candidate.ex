defmodule Ex4pmCore.CapsuleGraph.Candidate do
  @moduledoc false

  alias Ex4pmCore.CapsuleGraph.{Runtime, Subject, Transport}

  @enforce_keys [:id, :subject, :runtime, :transport, :capabilities, :evidence]
  defstruct [:id, :subject, :runtime, :transport, :capabilities, :evidence]

  def new(
        id,
        %Subject{} = subject,
        %Runtime{} = runtime,
        %Transport{} = transport,
        capabilities,
        evidence
      )
      when is_binary(id) and id != "" and is_list(capabilities) and is_list(evidence) do
    {:ok,
     %__MODULE__{
       id: id,
       subject: subject,
       runtime: runtime,
       transport: transport,
       capabilities: capabilities,
       evidence: evidence
     }}
  end

  def new(_, _, _, _, _, _), do: {:error, {:refused, :invalid_capsule_candidate}}
end
