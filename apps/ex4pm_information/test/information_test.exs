defmodule Ex4pm.InformationTest do
  use ExUnit.Case, async: false

  alias Ex4pm.Evidence.Store
  alias Ex4pm.Information

  @raw %{
    "objects" => %{
      "o1" => %{"type" => "Order"},
      "o2" => %{"type" => "Order"}
    },
    "events" => %{
      "e1" => %{
        "activity" => "create",
        "timestamp" => "2026-01-01T00:00:00Z",
        "objects" => ["o1"]
      },
      "e2" => %{
        "activity" => "ship",
        "timestamp" => "2026-01-01T00:01:00Z",
        "objects" => ["o1"]
      },
      "e3" => %{
        "activity" => "create",
        "timestamp" => "2026-01-01T00:02:00Z",
        "objects" => ["o2"]
      },
      "e4" => %{
        "activity" => "ship",
        "timestamp" => "2026-01-01T00:04:00Z",
        "objects" => ["o2"]
      }
    }
  }

  test "DfCM manifest preserves implemented and future interoperability edges" do
    manifest = Information.manifest()

    assert manifest.protocol == "ex4pm.information/1"
    assert manifest.release == "26.8.22"
    assert manifest.architecture.execution_plane == :reactor
    assert manifest.architecture.do_authority == Ex4pm.Evidence.BRCE

    transport_ids = Enum.map(manifest.transports, & &1.id)
    assert :beam_in_process in transport_ids
    assert :jsonl_stdio in transport_ids
    assert :wasm4pm in transport_ids
    assert :pm4py in transport_ids
    assert :clap_noun_verb_any in transport_ids
    assert :mcp in transport_ids

    candidate_ids = Enum.map(manifest.candidate_capabilities, & &1.id)
    assert "runtime.operate" in candidate_ids
    assert "ash.mutate" in candidate_ids
    assert Enum.all?(manifest.candidate_capabilities, &(&1.admitted == false))
  end

  test "manifest list and describe are the only direct one-hop fast path and create no receipts" do
    before_count = length(Store.all())

    assert "process.discover" in Information.list()
    assert {:ok, description} = Information.describe("process.discover")
    assert description.execution == :reactor
    assert Information.manifest().architecture.direct_fast_path == [:manifest, :list, :describe]
    assert length(Store.all()) == before_count
  end

  test "unknown capabilities are typed refusals with zero handler actuation and zero receipts" do
    before_count = length(Store.all())

    assert {:ok, response} =
             Information.execute(%{
               "protocol" => "ex4pm.information/1",
               "capability" => "Elixir.System.cmd",
               "input" => %{}
             })

    assert response.status == :refused
    assert response.refusal.code == :unknown_capability
    assert response.provenance.admitted == false
    assert response.provenance.actuated == false
    assert response.receipts.information == nil
    assert length(Store.all()) == before_count
  end

  test "protocol mismatch and malformed fields are refused before execution receipts" do
    before_count = length(Store.all())

    assert {:ok, wrong_version} =
             Information.execute(%{
               "protocol" => "ex4pm.information/1",
               "version" => "99.0.0",
               "capability" => "system.contracts"
             })

    assert wrong_version.status == :refused
    assert wrong_version.refusal.code == :unsupported_protocol_version

    assert {:ok, unknown_field} =
             Information.execute(%{
               "protocol" => "ex4pm.information/1",
               "capability" => "system.contracts",
               "ambient_module" => "Elixir.System"
             })

    assert unknown_field.status == :refused
    assert unknown_field.refusal.code == :unknown_protocol_field
    assert length(Store.all()) == before_count
  end

  test "public Ash reads execute through Reactor while mutations and arbitrary resources are refused" do
    assert {:ok, catalog_response} =
             Information.execute(%{
               "protocol" => "ex4pm.information/1",
               "capability" => "ash.catalog"
             })

    assert catalog_response.status == :ok
    assert catalog_response.receipts.information
    assert Enum.any?(catalog_response.result, &(&1.short_name == "event"))

    assert {:ok, read_response} =
             Information.execute(%{
               "protocol" => "ex4pm.information/1",
               "capability" => "ash.read",
               "input" => %{
                 "resource" => "event",
                 "action" => "read",
                 "params" => %{}
               }
             })

    assert read_response.status == :ok
    assert read_response.standing == :alive
    assert is_list(read_response.result)
    assert read_response.provenance.action_type == :read
    assert read_response.receipts.information

    before_refusal = length(Store.all())

    assert {:ok, mutation_response} =
             Information.execute(%{
               "protocol" => "ex4pm.information/1",
               "capability" => "ash.read",
               "input" => %{
                 "resource" => "event",
                 "action" => "create",
                 "params" => %{}
               }
             })

    assert mutation_response.status == :refused
    assert mutation_response.refusal.code == :ash_mutation_not_admitted
    assert mutation_response.receipts.information == nil
    assert length(Store.all()) == before_refusal

    assert {:ok, arbitrary_response} =
             Information.execute(%{
               "protocol" => "ex4pm.information/1",
               "capability" => "ash.read",
               "input" => %{
                 "resource" => "Elixir.System",
                 "action" => "read",
                 "params" => %{}
               }
             })

    assert arbitrary_response.status == :refused
    assert arbitrary_response.refusal.code == :unknown_ash_resource
  end

  test "discovery executes the exact admitted subject through Reactor and returns replayable layered receipts" do
    assert {:ok, response} =
             Information.execute(%{
               "protocol" => "ex4pm.information/1",
               "request_id" => "fortune5-discovery-1",
               "capability" => "process.discover",
               "input" => %{
                 "subject" => @raw,
                 "object_type" => "Order"
               },
               "options" => %{
                 "engine" => "beam",
                 "algorithm" => "dfg"
               }
             })

    assert response.status == :ok
    assert response.standing == :alive
    assert response.request_id == "fortune5-discovery-1"
    assert response.result["type"] == "dfg"
    assert response.result["trace_count"] == 2
    assert [%{"source" => "create", "target" => "ship"}] = response.result["edges"]
    assert is_binary(response.receipts.information_pending)
    assert is_binary(response.receipts.information)
    assert [_underlying] = response.receipts.underlying
    assert {:ok, %{replay: :chain_match}} = Ex4pm.replay(response.receipts.information)
  end

  test "canonical DFG JSON interchange round-trips from discovery into simulation" do
    assert {:ok, discovery} =
             Information.execute(%{
               "capability" => "process.discover",
               "input" => %{"subject" => @raw, "object_type" => "Order"},
               "options" => %{"engine" => "beam"}
             })

    assert discovery.status == :ok

    assert {:ok, simulation} =
             Information.execute(%{
               "capability" => "process.simulate",
               "input" => %{"model" => discovery.result},
               "options" => %{"engine" => "beam", "max_depth" => 12, "max_paths" => 128}
             })

    assert simulation.status == :ok
    assert simulation.standing == :alive
    assert simulation.result["paths"] == [["create", "ship"]]
    assert simulation.result["path_count"] == 1
  end

  test "JSON dispatch produces one machine-readable protocol envelope" do
    request =
      Jason.encode!(%{
        "protocol" => "ex4pm.information/1",
        "capability" => "engine.candidates",
        "input" => %{"operation" => "discover"}
      })

    assert {:ok, encoded} = Information.dispatch_json(request)
    assert {:ok, decoded} = Jason.decode(encoded)
    assert decoded["protocol"] == "ex4pm.information/1"
    assert decoded["version"] == "26.8.22"
    assert decoded["status"] == "ok"
    assert decoded["receipts"]["information"]
    assert is_list(decoded["result"])
  end

  test "execution limits and operation names are bounded instead of atomized" do
    assert {:ok, bad_limit} =
             Information.execute(%{
               "capability" => "system.contracts",
               "limits" => %{"max_concurrency" => 65}
             })

    assert bad_limit.status == :refused
    assert bad_limit.refusal.code == :invalid_concurrency

    assert {:ok, bad_operation} =
             Information.execute(%{
               "capability" => "engine.candidates",
               "input" => %{"operation" => "erlang.system_info"}
             })

    assert bad_operation.status == :refused
    assert bad_operation.refusal.code == :unknown_operation
    assert bad_operation.receipts.information
  end
end
