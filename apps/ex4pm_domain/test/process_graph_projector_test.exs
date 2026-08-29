defmodule Ex4pm.Domain.ProcessGraphProjectorTest do
  @moduledoc """
  Real, no-mock coverage of `Ex4pm.Domain.ProcessGraphProjector` -- both as a
  plain function against literal fixtures, and wired as a real Ash module
  calculation on `Ex4pm.Domain.ProcessModel` against the resource's real ETS
  data layer.
  """
  use ExUnit.Case, async: false

  alias Ex4pm.Domain.{ProcessGraphProjector, ProcessModel}

  describe "topology/1 (plain function)" do
    test "acyclic model gets a real topological order and one component" do
      model = %{"nodes" => ["a", "b", "c"], "edges" => [["a", "b"], ["b", "c"]]}

      assert %{topsort: topsort, components: components} = ProcessGraphProjector.topology(model)
      assert Enum.sort(topsort) == ["a", "b", "c"]
      assert Enum.find_index(topsort, &(&1 == "a")) < Enum.find_index(topsort, &(&1 == "b"))
      assert length(components) == 1
    end

    test "cyclic model gets a real nil topsort, not a crash" do
      model = %{"nodes" => ["a", "b"], "edges" => [["a", "b"], ["b", "a"]]}

      assert %{topsort: nil} = ProcessGraphProjector.topology(model)
    end

    test "disconnected nodes produce real separate components" do
      model = %{"nodes" => ["a", "b", "x", "y"], "edges" => [["a", "b"], ["x", "y"]]}

      assert %{components: components} = ProcessGraphProjector.topology(model)
      assert length(components) == 2
    end

    test "empty model produces real empty topology, not an error" do
      assert %{topsort: [], components: []} = ProcessGraphProjector.topology(%{})
    end
  end

  describe "wired as a real Ash module calculation" do
    test "loading :topology on a real ETS-backed ProcessModel record returns real projected topology" do
      record =
        ProcessModel
        |> Ash.Changeset.for_create(:create, %{
          subject_hash:
            "sha256:#{:crypto.hash(:sha256, "fixture") |> Base.encode16(case: :lower)}",
          algorithm: :discover,
          engine: :beam,
          model_hash: "sha256:#{:crypto.hash(:sha256, "model") |> Base.encode16(case: :lower)}",
          standing: :alive,
          model: %{"nodes" => ["a", "b"], "edges" => [["a", "b"]]}
        })
        |> Ash.create!()

      loaded = Ash.load!(record, [:topology])

      assert %{topsort: topsort, components: [_]} = loaded.topology
      assert Enum.sort(topsort) == ["a", "b"]
    end
  end
end
