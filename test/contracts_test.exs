defmodule Ex4pm.ContractsTest do
  use ExUnit.Case, async: true

  test "ontology, SHACL, WIT, and receipt schema close into one contract hash" do
    assert {:ok, contract} = Ex4pm.Contracts.verify()
    assert contract.standing == :alive
    assert is_binary(contract.contract_hash)

    assert Map.keys(contract.artifacts) |> Enum.sort() == [
             :ontology,
             :receipt_schema,
             :shacl,
             :wit
           ]

    assert Enum.all?(contract.artifacts, fn {_id, artifact} -> artifact.hash =~ "sha256:" end)
  end
end
