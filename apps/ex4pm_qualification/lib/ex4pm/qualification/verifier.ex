defmodule Ex4pm.Qualification.Verifier do
  @moduledoc "Independent crown verifier. Stored standing is never trusted."

  alias Ex4pm.Core.Hash

  @rails ~w(beam ex4pm_plan wasm nif remote)

  def verify(crown) when is_map(crown) do
    checks = %{
      identity: sha?(field(crown, "source_sha")) and sha?(field(crown, "tree_sha")),
      powl: powl_ok?(field(crown, "powl")),
      rails: rails_ok?(field(crown, "rails")),
      global: global_ok?(field(crown, "global")),
      commands: commands_ok?(field(crown, "commands")),
      falsifiers: field(crown, "falsifiers") == true
    }

    computed_hash = evidence_hash(crown)
    supplied_hash = field(crown, "evidence_hash")
    hash_ok = is_nil(supplied_hash) or supplied_hash == computed_hash
    checks = Map.put(checks, :evidence_hash, hash_ok)

    if Enum.all?(checks, fn {_key, value} -> value end) do
      {:ok, %{standing: :alive, checks: checks, evidence_hash: computed_hash}}
    else
      {:error, %{standing: :partial_alive, checks: checks, evidence_hash: computed_hash}}
    end
  end

  def evidence_hash(crown) do
    crown |> drop_field("standing") |> drop_field("evidence_hash") |> Hash.digest()
  end

  defp powl_ok?(powl) when is_map(powl) do
    field(powl, "soundness") == true and field(powl, "completeness") == true and
      field(powl, "correspondence") == true and field(powl, "sabotage") == true and
      field(powl, "compiler_refinement") == true
  end

  defp powl_ok?(_), do: false

  defp rails_ok?(rails) when is_map(rails) do
    Enum.all?(@rails, fn rail ->
      case field(rails, rail) do
        value when is_map(value) ->
          field(value, "standing") in [:alive, "ALIVE", "alive"] and
            nonempty?(field(value, "artifact_digest")) and nonempty?(field(value, "result_hash"))

        _ ->
          false
      end
    end)
  end

  defp rails_ok?(_), do: false

  defp global_ok?(global) when is_map(global) do
    hosts = field(global, "hosts") || []
    regions = field(global, "regions") || []
    domains = field(global, "fault_domains") || []

    length(Enum.uniq(hosts)) >= 5 and length(Enum.uniq(regions)) >= 2 and
      length(Enum.uniq(domains)) >= 3 and field(global, "tls_verified") == true and
      field(global, "pre_do_refusal") == true and field(global, "during_do_ambiguous") == true and
      field(global, "no_duplicate_do") == true and field(global, "mixed_version_refused") == true and
      field(global, "clock_skew_safe") == true
  end

  defp global_ok?(_), do: false

  defp commands_ok?(commands) when is_list(commands),
    do: commands != [] and Enum.all?(commands, &(field(&1, "exit") == 0))

  defp commands_ok?(_), do: false

  defp sha?(value), do: is_binary(value) and String.match?(value, ~r/^[0-9a-f]{40}$/)
  defp nonempty?(value), do: is_binary(value) and byte_size(value) > 0

  defp field(map, key) when is_map(map) do
    Map.get(map, key) ||
      try do
        Map.get(map, String.to_existing_atom(key))
      rescue
        ArgumentError -> nil
      end
  end

  defp field(_, _), do: nil

  defp drop_field(map, key) do
    map
    |> Map.delete(key)
    |> then(fn value ->
      try do
        Map.delete(value, String.to_existing_atom(key))
      rescue
        ArgumentError -> value
      end
    end)
  end
end
