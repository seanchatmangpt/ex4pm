import { execSync } from 'child_process';

export interface BeamClusterStats {
  memory_total_mb: number;
  memory_ets_mb: number;
  process_count: number;
  process_limit: number;
  ets_count: number;
  atom_count: number;
  ocel_events: number;
  ocel_objects: number;
  receipts_count: number;
}

export function queryBeamClusterStats(): BeamClusterStats {
  const elixirCode = `
    Jason.encode!(%{
      memory_total_mb: Float.round(:erlang.memory(:total) / 1048576, 2),
      memory_ets_mb: Float.round(:erlang.memory(:ets) / 1048576, 2),
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      ets_count: :erlang.system_info(:ets_count),
      atom_count: :erlang.system_info(:atom_count),
      ocel_events: (case Ash.read(Ex4pm.Domain.Event) do {:ok, l} -> length(l); _ -> 0 end),
      ocel_objects: (case Ash.read(Ex4pm.Domain.Object) do {:ok, l} -> length(l); _ -> 0 end),
      receipts_count: (case Ash.read(Ex4pm.Domain.ReceiptProjection) do {:ok, l} -> length(l); _ -> 0 end)
    }) |> IO.puts()
  `.replace(/\\s+/g, ' ').trim();

  const rawOutput = execSync(
    `kubectl exec deployment/ex4pm -- bin/ex4pm_umbrella rpc "${elixirCode}"`,
    { encoding: 'utf-8', timeout: 10000 }
  );

  const lines = rawOutput.trim().split('\n');
  const lastLine = lines[lines.length - 1];
  return JSON.parse(lastLine);
}
