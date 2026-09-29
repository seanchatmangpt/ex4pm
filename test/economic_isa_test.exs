defmodule Ex4pm.EconomicISATest do
  use ExUnit.Case, async: true

  alias Ex4pm.{EconomicISA, Event, Refusal}

  test "common-path economic activities round-trip in exactly one byte" do
    for operation <- EconomicISA.registry() do
      assert {:ok, <<opcode>> = encoded} = EconomicISA.encode(operation.name)
      assert byte_size(encoded) == 1
      assert opcode == operation.opcode
      assert {:ok, ^operation} = EconomicISA.decode(encoded)
    end
  end

  test "registry is deterministic, unique, and excludes reserved boundary bytes" do
    registry = EconomicISA.registry()
    opcodes = Enum.map(registry, & &1.opcode)
    names = Enum.map(registry, & &1.name)

    assert opcodes == Enum.uniq(opcodes)
    assert names == Enum.uniq(names)
    refute EconomicISA.unknown_opcode() in opcodes
    refute EconomicISA.escape_opcode() in opcodes

    for operation <- registry do
      assert EconomicISA.category(operation.opcode) == operation.category
    end
  end

  test "unknown and unassigned bytes stay visible instead of being silently coerced" do
    assert {:ok, %{name: :unknown, opcode: 0x00, category: :unknown}} =
             EconomicISA.decode(<<0x00>>)

    assert {:error, %Refusal{code: :unknown_economic_opcode, details: %{category: :market}}} =
             EconomicISA.decode(<<0x1F>>)
  end

  test "escape byte preserves extended ontology identifiers losslessly" do
    semantic_id = "https://example.org/economic/activity/custom-v1"

    assert {:ok, encoded} = EconomicISA.encode_extended(semantic_id)
    assert <<0xFF, _::binary>> = encoded

    assert {:ok,
            %{
              name: :extended,
              opcode: 0xFF,
              category: :extended,
              semantic_id: ^semantic_id
            }} = EconomicISA.decode(encoded)
  end

  test "malformed escape records are typed refusals" do
    assert {:error, %Refusal{code: :invalid_extended_economic_opcode}} =
             EconomicISA.decode(<<0xFF, 0x00>>)
  end

  test "economic activity projects into canonical OCEL event without a competing event type" do
    relationships = [
      %{object_id: "order-1", qualifier: "order"},
      %{object_id: "venue-x", qualifier: "venue"}
    ]

    assert {:ok, %Event{} = event} =
             EconomicISA.to_event(:fill,
               id: "fill-1",
               timestamp: ~U[2026-09-10 22:24:00Z],
               object_ids: ["venue-x", "order-1", "order-1"],
               relationships: relationships,
               provenance: %{"source" => "matching-engine"},
               authority: %{"policy" => "mm-v1"},
               value: %{"amount" => "12.34", "currency" => "USD"},
               attributes: %{"quantity" => 100}
             )

    assert event.activity == "fill"
    assert event.object_ids == ["order-1", "venue-x"]
    assert event.relationships == relationships
    assert event.attributes["economic_opcode"] == 0x21
    assert event.attributes["economic_opcode_hex"] == "0x21"
    assert event.attributes["economic_category"] == "transaction"
    assert event.attributes["economic_isa"] == "ex4pm-economic-isa/v1"
    assert event.attributes["quantity"] == 100
    assert event.attributes["provenance"] == %{"source" => "matching-engine"}
    assert event.attributes["authority"] == %{"policy" => "mm-v1"}
    assert event.attributes["economic_value"] == %{"amount" => "12.34", "currency" => "USD"}
  end

  test "OCEL projection refuses incomplete event identity" do
    assert {:error, %Refusal{code: :missing_economic_event_field, details: %{field: :id}}} =
             EconomicISA.to_event(:sale, timestamp: "2026-09-10T22:24:00Z")
  end
end
