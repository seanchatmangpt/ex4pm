defmodule Ex4pm.Information.Handlers do
  @moduledoc """
  Explicit handler table for admitted information capabilities.

  This module is the only bridge from registry handler identifiers to existing
  ex4pm/Ash APIs. It deliberately has no generic apply/module dispatch path.
  """

  alias Ex4pm.Information.{AshCatalog, Interop, Protocol}
  alias Ex4pm.Information.Registry.Admitted
  alias Ex4pm.Refusal

  @max_file_bytes 67_108_864

  def execute(:system_doctor, %Admitted{}) do
    candidates =
      [:discover, :conform, :simulate, :optimize, :plan]
      |> Map.new(fn operation ->
        {operation, Ex4pm.capabilities(operation) |> Enum.map(&Protocol.json_safe/1)}
      end)

    case Ex4pm.contracts() do
      {:ok, contract} ->
        ok(
          %{operations: candidates, contracts: Protocol.json_safe(contract)},
          :partial_alive,
          [],
          %{inspection_only: true, engine_execution: false}
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  def execute(:system_contracts, %Admitted{}) do
    case Ex4pm.contracts() do
      {:ok, contract} ->
        ok(Protocol.json_safe(contract), contract.standing, [], %{contract_verification: true})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def execute(:engine_candidates, %Admitted{input: input}) do
    with {:ok, operation} <- operation_atom(input["operation"]) do
      value = operation |> Ex4pm.capabilities() |> Enum.map(&Protocol.json_safe/1)
      ok(value, :partial_alive, [], %{operation: operation, selected: false})
    end
  end

  def execute(:ash_catalog, %Admitted{}) do
    ok(AshCatalog.catalog(), :alive, [], %{ash_action_executed: false})
  end

  def execute(:ash_read, %Admitted{input: input, context: context, resolved: resolved}) do
    case AshCatalog.read(resolved, input["params"], context) do
      {:ok, records} ->
        ok(Protocol.json_safe(records), :alive, [], %{
          ash_resource: inspect(resolved.resource),
          ash_action: resolved.action,
          action_type: :read
        })

      {:error, reason} ->
        {:error,
         Refusal.new(:ash_read_failed, "admitted Ash read action failed",
           details: %{reason: inspect(reason, limit: 20, printable_limit: 2_000)}
         )}
    end
  end

  def execute(:process_ingest, %Admitted{input: input, options: options}) do
    case Ex4pm.ingest(input["subject"], project?: options["project"]) do
      {:ok, log} ->
        ok(Interop.event_log_summary(log), :alive, [], %{
          operation: :ingest,
          subject_hash: log.subject.hash
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  def execute(:process_ingest_xes, %Admitted{input: input, options: options}) do
    case Ex4pm.ingest_xes(input["xml"], project?: options["project"]) do
      {:ok, log} ->
        ok(Interop.event_log_summary(log), :alive, [], %{
          operation: :ingest_xes,
          subject_hash: log.subject.hash
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  def execute(:process_discover, %Admitted{input: input, options: options}) do
    with {:ok, opts} <- analysis_options(input, options, :discover),
         {:ok, run} <- Ex4pm.discover(input["subject"], opts) do
      run_ok(run)
    end
  end

  def execute(:process_discover_file, %Admitted{input: input, options: options}) do
    with {:ok, bytes} <- read_bounded_file(input["path"]),
         {:ok, subject} <- decode_json_file(bytes, input["path"]),
         {:ok, opts} <- analysis_options(input, options, :discover),
         {:ok, run} <- Ex4pm.discover(subject, opts) do
      run_ok(run, %{source_path: Path.expand(input["path"])})
    end
  end

  def execute(:process_discover_xes, %Admitted{input: input, options: options}) do
    with {:ok, log} <- Ex4pm.ingest_xes(input["xml"]),
         {:ok, opts} <-
           analysis_options(%{"object_type" => input["case_object_type"]}, options, :discover),
         {:ok, run} <- Ex4pm.discover(log, opts) do
      run_ok(run, %{source_format: :xes})
    end
  end

  def execute(:process_discover_xes_file, %Admitted{input: input, options: options}) do
    with {:ok, bytes} <- read_bounded_file(input["path"]),
         {:ok, log} <- Ex4pm.ingest_xes(bytes),
         {:ok, opts} <-
           analysis_options(%{"object_type" => input["case_object_type"]}, options, :discover),
         {:ok, run} <- Ex4pm.discover(log, opts) do
      run_ok(run, %{source_format: :xes, source_path: Path.expand(input["path"])})
    end
  end

  def execute(:process_conform, %Admitted{input: input, options: options}) do
    with {:ok, model} <- Interop.decode_model(input["model"]),
         {:ok, opts} <- analysis_options(input, options, :conform),
         {:ok, run} <- Ex4pm.conform(input["subject"], model, opts) do
      run_ok(run)
    end
  end

  def execute(:process_simulate, %Admitted{input: input, options: options}) do
    with {:ok, model} <- Interop.decode_model(input["model"]),
         {:ok, opts} <- analysis_options(input, options, :simulate),
         {:ok, run} <- Ex4pm.simulate(model, opts) do
      run_ok(run)
    end
  end

  def execute(:process_optimize, %Admitted{input: input, options: options}) do
    with {:ok, model} <- Interop.decode_model(input["model"]),
         {:ok, opts} <- analysis_options(input, options, :optimize),
         {:ok, run} <- Ex4pm.optimize(input["subject"], model, opts) do
      run_ok(run)
    end
  end

  def execute(:process_plan, %Admitted{input: input}) do
    case Ex4pm.plan(input["problem"]) do
      {:ok, run} -> run_ok(run)
      {:error, reason} -> {:error, reason}
    end
  end

  def execute(:receipt_replay, %Admitted{input: input}) do
    hash = input["hash"]

    case Ex4pm.replay(hash) do
      {:ok, replay} ->
        ok(Protocol.json_safe(replay), replay.standing, [hash], %{
          operation: :replay,
          replay: replay.replay
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp analysis_options(input, options, operation) do
    with {:ok, engine} <- engine_atom(options["engine"]),
         {:ok, algorithm} <- algorithm_atom(Map.get(options, "algorithm", "dfg")) do
      opts =
        []
        |> maybe_put(:engine, engine)
        |> maybe_put(:algorithm, if(operation == :discover, do: algorithm, else: nil))
        |> maybe_put(:object_type, Map.get(input, "object_type"))
        |> maybe_put(:project?, Map.get(options, "project"))
        |> maybe_put(:max_depth, Map.get(options, "max_depth"))
        |> maybe_put(:max_paths, Map.get(options, "max_paths"))

      {:ok, opts}
    end
  end

  defp engine_atom("auto"), do: {:ok, nil}
  defp engine_atom("beam"), do: {:ok, :beam}
  defp engine_atom("ex4pm_plan"), do: {:ok, :ex4pm_plan}
  defp engine_atom("wasm"), do: {:ok, :wasm}
  defp engine_atom("nif"), do: {:ok, :nif}
  defp engine_atom("remote"), do: {:ok, :remote}

  defp engine_atom(other) do
    {:error,
     Refusal.new(:unknown_engine, "requested engine is not in the admitted DfCM engine graph",
       details: %{engine: other, admitted: ~w(auto beam ex4pm_plan wasm nif remote)}
     )}
  end

  defp algorithm_atom("dfg"), do: {:ok, :dfg}
  defp algorithm_atom("variants"), do: {:ok, :variants}

  defp algorithm_atom(other) do
    {:error,
     Refusal.new(:unsupported_algorithm, "requested discovery algorithm is not admitted",
       details: %{algorithm: other, admitted: ~w(dfg variants)}
     )}
  end

  defp operation_atom("discover"), do: {:ok, :discover}
  defp operation_atom("conform"), do: {:ok, :conform}
  defp operation_atom("simulate"), do: {:ok, :simulate}
  defp operation_atom("optimize"), do: {:ok, :optimize}
  defp operation_atom("plan"), do: {:ok, :plan}

  defp operation_atom(other) do
    {:error,
     Refusal.new(:unknown_operation, "engine candidate operation is not admitted",
       details: %{operation: other, admitted: ~w(discover conform simulate optimize plan)}
     )}
  end

  defp read_bounded_file(path) when is_binary(path) do
    expanded = Path.expand(path)

    with {:ok, stat} <- File.lstat(expanded),
         :ok <- regular_file(stat, expanded),
         :ok <- bounded_file(stat, expanded),
         {:ok, bytes} <- File.read(expanded) do
      {:ok, bytes}
    else
      {:error, %Refusal{} = refusal} ->
        {:error, refusal}

      {:error, reason} ->
        {:error,
         Refusal.new(:file_read_failed, "file could not be read",
           details: %{path: expanded, reason: inspect(reason)}
         )}
    end
  end

  defp regular_file(%File.Stat{type: :regular}, _path), do: :ok

  defp regular_file(%File.Stat{type: type}, path) do
    {:error,
     Refusal.new(:non_regular_file_refused, "interop file source must be a regular file",
       details: %{path: path, type: type}
     )}
  end

  defp bounded_file(%File.Stat{size: size}, _path) when size <= @max_file_bytes, do: :ok

  defp bounded_file(%File.Stat{size: size}, path) do
    {:error,
     Refusal.new(:file_too_large, "interop file exceeds the admitted byte bound",
       details: %{path: path, bytes: size, maximum: @max_file_bytes}
     )}
  end

  defp decode_json_file(bytes, path) do
    case Jason.decode(bytes) do
      {:ok, value} ->
        {:ok, value}

      {:error, reason} ->
        {:error,
         Refusal.new(:invalid_ocel_json, "OCEL file is not valid JSON",
           details: %{path: Path.expand(path), reason: Exception.message(reason)}
         )}
    end
  end

  defp run_ok(run, extra_provenance \\ %{}) do
    ok(
      Interop.run_value(run),
      run.standing,
      Interop.underlying_receipts(run),
      Map.merge(Interop.run_provenance(run), extra_provenance)
    )
  end

  defp ok(value, standing, receipts, provenance) do
    {:ok,
     %{
       value: value,
       standing: standing,
       underlying_receipts: receipts,
       provenance: provenance
     }}
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, false), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
