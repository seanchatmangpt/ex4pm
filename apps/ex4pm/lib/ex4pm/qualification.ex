defmodule Ex4pm.Qualification do
  @moduledoc "Machine-readable identity and semantic fingerprints for bounded qualification runs."

  alias Ex4pm.Core.Hash

  def environment do
    observation = %{
      source_sha: System.get_env("EX4PM_SUBJECT_SHA"),
      node: Node.self(),
      connected_nodes: Node.list() |> Enum.sort(),
      otp_release: System.otp_release(),
      erts_version: :erlang.system_info(:version) |> to_string(),
      system_architecture: :erlang.system_info(:system_architecture) |> to_string(),
      word_size: :erlang.system_info(:wordsize),
      schedulers: :erlang.system_info(:schedulers),
      schedulers_online: :erlang.system_info(:schedulers_online),
      dirty_cpu_schedulers: :erlang.system_info(:dirty_cpu_schedulers),
      dirty_io_schedulers: :erlang.system_info(:dirty_io_schedulers),
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      distribution: Ex4pm.Runtime.Distributed.security_posture(),
      observed_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Map.put(observation, :observation_hash, Hash.digest(observation))
  end

  def execution_semantics(%{subject_hash: subject_hash, layers: layers}) do
    semantic = %{
      subject_hash: subject_hash,
      layers:
        Enum.map(layers, fn layer ->
          Enum.map(layer, fn item -> Map.fetch!(item, :result) end)
        end)
    }

    Map.put(semantic, :semantic_hash, Hash.digest(semantic))
  end
end
