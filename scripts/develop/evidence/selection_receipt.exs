defmodule Ex4pm.Develop.Evidence.SelectionReceipt do
  def issue(subject, evidence_ids, ctqs) do
    body=%{subject: subject,evidence_ids: Enum.sort(evidence_ids),ctqs: ctqs,authority: :select,actuation: false}
    Map.put(body,:digest,:crypto.hash(:sha256,:erlang.term_to_binary(body))|>Base.encode16(case: :lower))
  end
end
