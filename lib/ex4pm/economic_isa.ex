defmodule Ex4pm.EconomicISA do
  @moduledoc """
  Compact economic activity instruction set for nexus/edge execution.

  The common-path wire representation is exactly one byte. `0x00` is reserved for
  UNKNOWN/NULL and `0xFF` is an escape prefix for an extended semantic identifier.
  The byte is only the canonical verb; OCEL objects, relationships, attributes,
  authority, provenance, quantities, and values remain in the canonical `Ex4pm.Event`
  representation.

  This module deliberately does not create a competing event-log format. `to_event/2`
  projects a byte activity into the existing OCEL-v2-compatible semantic IR.
  """

  alias Ex4pm.{Event, Refusal}

  @unknown 0x00
  @escape 0xFF

  @ranges %{
    market: 0x01..0x1F,
    transaction: 0x20..0x3F,
    payment_settlement: 0x40..0x5F,
    logistics_transfer: 0x60..0x7F,
    contract_rights: 0x80..0x9F,
    production_service: 0xA0..0xBF,
    accounting_finance: 0xC0..0xDF,
    governance_authority: 0xE0..0xEF,
    extension: 0xF0..0xFE
  }

  # 80/20 seed vocabulary. IDs are intentionally sparse so each range can grow
  # without renumbering already-emitted receipts.
  @operations [
    %{name: :quote, opcode: 0x01, category: :market},
    %{name: :offer, opcode: 0x02, category: :market},
    %{name: :bid, opcode: 0x03, category: :market},
    %{name: :ask, opcode: 0x04, category: :market},
    %{name: :order, opcode: 0x20, category: :transaction},
    %{name: :fill, opcode: 0x21, category: :transaction},
    %{name: :sale, opcode: 0x22, category: :transaction},
    %{name: :purchase, opcode: 0x23, category: :transaction},
    %{name: :invoice, opcode: 0x40, category: :payment_settlement},
    %{name: :pay, opcode: 0x41, category: :payment_settlement},
    %{name: :settle, opcode: 0x42, category: :payment_settlement},
    %{name: :refund, opcode: 0x43, category: :payment_settlement},
    %{name: :ship, opcode: 0x60, category: :logistics_transfer},
    %{name: :deliver, opcode: 0x61, category: :logistics_transfer},
    %{name: :transfer, opcode: 0x62, category: :logistics_transfer},
    %{name: :license, opcode: 0x80, category: :contract_rights},
    %{name: :subscribe, opcode: 0x81, category: :contract_rights},
    %{name: :renew, opcode: 0x82, category: :contract_rights},
    %{name: :claim, opcode: 0x83, category: :contract_rights},
    %{name: :manufacture, opcode: 0xA0, category: :production_service},
    %{name: :provide_service, opcode: 0xA1, category: :production_service},
    %{name: :discover, opcode: 0xA2, category: :production_service},
    %{name: :prove, opcode: 0xA3, category: :production_service},
    %{name: :design, opcode: 0xA4, category: :production_service},
    %{name: :recognize_revenue, opcode: 0xC0, category: :accounting_finance},
    %{name: :accrue_receivable, opcode: 0xC1, category: :accounting_finance},
    %{name: :realize_value, opcode: 0xC2, category: :accounting_finance},
    %{name: :authorize, opcode: 0xE0, category: :governance_authority},
    %{name: :attest, opcode: 0xE1, category: :governance_authority},
    %{name: :refuse, opcode: 0xE2, category: :governance_authority}
  ]

  @by_name Map.new(@operations, &{&1.name, &1})
  @by_opcode Map.new(@operations, &{&1.opcode, &1})

  @type opcode :: 0..255
  @type operation :: atom()

  def unknown_opcode, do: @unknown
  def escape_opcode, do: @escape
  def ranges, do: @ranges
  def registry, do: @operations

  @doc "Encode a registered economic activity to its one-byte common-path representation."
  def encode(name) when is_binary(name) do
    try do
      encode(String.to_existing_atom(name))
    rescue
      ArgumentError -> unknown_operation(name)
    end
  end

  def encode(name) when is_atom(name) do
    case Map.fetch(@by_name, name) do
      {:ok, %{opcode: opcode}} -> {:ok, <<opcode>>}
      :error -> unknown_operation(name)
    end
  end

  def encode(other), do: unknown_operation(other)

  @doc "Decode a common-path byte or an extended semantic identifier."
  def decode(<<@unknown>>), do: {:ok, %{name: :unknown, opcode: @unknown, category: :unknown}}

  def decode(<<@escape, size::unsigned-big-16, semantic_id::binary-size(size)>>) do
    {:ok, %{name: :extended, opcode: @escape, category: :extended, semantic_id: semantic_id}}
  end

  def decode(<<@escape, _rest::binary>> = binary) do
    {:error,
     Refusal.new(:invalid_extended_economic_opcode, "extended economic opcode is malformed",
       subject: binary
     )}
  end

  def decode(<<opcode>>) do
    case Map.fetch(@by_opcode, opcode) do
      {:ok, operation} -> {:ok, operation}
      :error -> unknown_opcode(opcode)
    end
  end

  def decode(other) do
    {:error,
     Refusal.new(:invalid_economic_opcode, "economic opcode must be one byte or a valid escape record",
       subject: other
     )}
  end

  @doc "Encode an ontology/semantic identifier outside the one-byte registry without losing it."
  def encode_extended(semantic_id) when is_binary(semantic_id) and byte_size(semantic_id) <= 65_535 do
    {:ok, <<@escape, byte_size(semantic_id)::unsigned-big-16, semantic_id::binary>>}
  end

  def encode_extended(semantic_id) do
    {:error,
     Refusal.new(:invalid_extended_semantic_id, "semantic identifier must be a binary <= 65535 bytes",
       subject: semantic_id
     )}
  end

  @doc "Lookup an operation by name or opcode."
  def lookup(name) when is_atom(name), do: Map.fetch(@by_name, name)
  def lookup(opcode) when is_integer(opcode), do: Map.fetch(@by_opcode, opcode)
  def lookup(_), do: :error

  @doc "Return the reserved category for any byte, whether or not it is assigned yet."
  def category(@unknown), do: :unknown
  def category(@escape), do: :extended

  def category(opcode) when is_integer(opcode) and opcode >= 0 and opcode <= 255 do
    Enum.find_value(@ranges, :unassigned, fn {category, range} ->
      if opcode in range, do: category
    end)
  end

  def category(_), do: :invalid

  @doc """
  Project an economic opcode into the existing canonical OCEL event IR.

  Required options: `:id`, `:timestamp`.
  Optional options: `:object_ids`, `:relationships`, `:attributes`, `:provenance`,
  `:authority`, and `:value`.
  """
  def to_event(activity, opts) when is_list(opts) do
    with {:ok, encoded} <- encode(activity),
         {:ok, operation} <- decode(encoded),
         {:ok, id} <- required_opt(opts, :id),
         {:ok, timestamp} <- required_opt(opts, :timestamp) do
      attributes =
        opts
        |> Keyword.get(:attributes, %{})
        |> Map.new()
        |> Map.merge(%{
          "economic_opcode" => operation.opcode,
          "economic_opcode_hex" => hex(operation.opcode),
          "economic_category" => Atom.to_string(operation.category),
          "economic_isa" => "ex4pm-economic-isa/v1"
        })
        |> maybe_put("provenance", Keyword.get(opts, :provenance))
        |> maybe_put("authority", Keyword.get(opts, :authority))
        |> maybe_put("economic_value", Keyword.get(opts, :value))

      {:ok,
       %Event{
         id: to_string(id),
         activity: Atom.to_string(operation.name),
         timestamp: normalize_timestamp(timestamp),
         object_ids: opts |> Keyword.get(:object_ids, []) |> Enum.map(&to_string/1) |> Enum.uniq() |> Enum.sort(),
         relationships: Keyword.get(opts, :relationships, []),
         attributes: attributes
       }}
    end
  end

  def to_event(activity, other) do
    {:error,
     Refusal.new(:invalid_economic_event_options, "economic event options must be a keyword list",
       subject: %{activity: activity, options: other}
     )}
  end

  defp required_opt(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> {:ok, value}
      :error ->
        {:error,
         Refusal.new(:missing_economic_event_field, "economic event is missing required field",
           details: %{field: key}
         )}
    end
  end

  defp unknown_operation(subject) do
    {:error,
     Refusal.new(:unknown_economic_activity, "economic activity is not registered", subject: subject)}
  end

  defp unknown_opcode(opcode) do
    {:error,
     Refusal.new(:unknown_economic_opcode, "economic opcode is unassigned",
       subject: opcode,
       details: %{category: category(opcode)}
     )}
  end

  defp hex(opcode), do: "0x" <> (opcode |> Integer.to_string(16) |> String.pad_leading(2, "0") |> String.upcase())

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp normalize_timestamp(%DateTime{} = timestamp), do: DateTime.to_iso8601(timestamp)
  defp normalize_timestamp(%NaiveDateTime{} = timestamp), do: NaiveDateTime.to_iso8601(timestamp)
  defp normalize_timestamp(timestamp), do: to_string(timestamp)
end
