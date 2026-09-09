defmodule Ex4pmCore.CapsuleGraph.ReplayTest do
  @moduledoc """
  Ex4pmCore.CapsuleGraph.Replay had zero test coverage and zero other callers anywhere in
  the repo before this file. Real Ex4pmCore.CapsuleGraph.Receipt structs (built through the
  real Candidate/Subject/Runtime/Transport constructors, no mocking) are hashed and verified
  end to end.
  """

  use ExUnit.Case, async: true

  alias Ex4pmCore.CapsuleGraph.{Candidate, Receipt, Replay, Runtime, Subject, Transport}

  defp real_candidate do
    repository = "#{Faker.Internet.user_name()}/#{Faker.Internet.slug()}"
    # Subject.sha requires a 40-char lowercase-hex string (a real git sha shape); derive one
    # from real Faker-generated content rather than hand-writing a literal.
    sha = :crypto.hash(:sha, Faker.Lorem.sentence()) |> Base.encode16(case: :lower)

    {:ok, subject} = Subject.new(repository, sha)
    {:ok, runtime} = Runtime.new(Enum.random(Runtime.kinds()), Faker.App.version(), "x86_64")
    {:ok, transport} = Transport.new(Enum.random(Transport.modes()), Faker.UUID.v4())

    Candidate.new(
      Faker.UUID.v4(),
      subject,
      runtime,
      transport,
      [Faker.Company.buzzword()],
      [%{observed: true, evidence: Faker.Lorem.word()}]
    )
  end

  test "verify/1 matches a genuine, untampered receipt" do
    {:ok, candidate} = real_candidate()
    input = %{payload: Faker.Lorem.paragraph()}
    output = %{result: Faker.Lorem.paragraph()}

    receipt = Receipt.new(candidate, input, output)

    assert Replay.verify(receipt) == {:ok, :match}
  end

  test "verify/1 refuses a receipt whose digest no longer matches its body" do
    {:ok, candidate} = real_candidate()
    input = %{payload: Faker.Lorem.paragraph()}
    output = %{result: Faker.Lorem.paragraph()}

    receipt = Receipt.new(candidate, input, output)
    tampered = %{receipt | output_digest: Faker.Lorem.characters(64) |> to_string()}

    assert Replay.verify(tampered) == {:error, {:refused, :capsule_receipt_mismatch}}
  end

  test "verify/1 refuses non-Receipt input instead of crashing (receipt-shaped map is not a verified receipt)" do
    {:ok, candidate} = real_candidate()
    input = %{payload: Faker.Lorem.paragraph()}
    output = %{result: Faker.Lorem.paragraph()}

    real_receipt = Receipt.new(candidate, input, output)
    receipt_shaped_map = Map.from_struct(real_receipt)

    assert Replay.verify(receipt_shaped_map) == {:error, {:refused, :invalid_capsule_receipt}}
    assert Replay.verify(nil) == {:error, {:refused, :invalid_capsule_receipt}}
    assert Replay.verify(Faker.Lorem.word()) == {:error, {:refused, :invalid_capsule_receipt}}
  end
end
