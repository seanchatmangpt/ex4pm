defmodule Ex4pm.Develop.Evidence.AdmissionToken do
  def issue(subject, generation, kind) when generation >= 0 do
    body={subject,generation,kind,:verify,false}
    %{body: body,digest: :crypto.hash(:sha256,:erlang.term_to_binary(body))|>Base.encode16(case: :lower)}
  end
  def verify(%{body: body,digest: digest}), do: if((:crypto.hash(:sha256,:erlang.term_to_binary(body))|>Base.encode16(case: :lower))==digest,do: :ok,else: {:refused,:token_drift})
end
