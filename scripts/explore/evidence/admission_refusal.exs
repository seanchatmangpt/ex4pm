defmodule Explore.Admission do
  @required [:identity,:authority,:bounded]
  def admit(subject) do
    missing=Enum.reject(@required,&Map.get(subject,&1,false))
    if missing==[], do: {:admitted,subject}, else: {:refused,{:missing,missing}}
  end
end
{:admitted,_}=Explore.Admission.admit(%{identity: true,authority: true,bounded: true})
{:refused,{:missing,[:authority]}}=Explore.Admission.admit(%{identity: true,bounded: true})
IO.inspect(%{candidate: :admission_refusal, standing: :alive})
