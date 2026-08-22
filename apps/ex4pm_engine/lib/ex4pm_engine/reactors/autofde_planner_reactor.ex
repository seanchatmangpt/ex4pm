defmodule Ex4pmEngine.Reactors.AutoFdePlannerReactor.PortRegistry do
  @moduledoc """
  Public-ETS-backed registry used to hand a spawned OS port/pid from a
  `RunScript` step's `run/3` across to `compensate/4` so it can find and kill the process.
  """

  use GenServer

  @table :ex4pm_autofde_port_registry
  @audit :ex4pm_autofde_port_audit

  def ensure_started! do
    case GenServer.whereis(__MODULE__) do
      nil ->
        case GenServer.start(__MODULE__, :ok, name: __MODULE__) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
        end

      _pid ->
        :ok
    end
  end

  @impl GenServer
  def init(:ok) do
    :ets.new(@table, [:named_table, :public, :set])
    :ets.new(@audit, [:named_table, :public, :set])
    {:ok, %{}}
  end

  def put(request_id, port, os_pid) do
    ensure_started!()
    :ets.insert(@table, {request_id, port, os_pid})
  end

  def get(request_id) do
    ensure_started!()

    case :ets.lookup(@table, request_id) do
      [{^request_id, port, os_pid}] -> {port, os_pid}
      [] -> nil
    end
  end

  def delete(request_id) do
    ensure_started!()
    :ets.delete(@table, request_id)
  end

  def record_kill(request_id, os_pid, outcome) do
    ensure_started!()
    :ets.insert(@audit, {request_id, os_pid, outcome})
  end

  def get_audit(request_id) do
    ensure_started!()

    case :ets.lookup(@audit, request_id) do
      [{^request_id, os_pid, outcome}] -> {os_pid, outcome}
      [] -> nil
    end
  end
end

defmodule Ex4pmEngine.Reactors.AutoFdePlannerReactor.RunScript do
  @moduledoc """
  Reactor step that executes an external planner command with ordered compensation.
  """

  use Reactor.Step

  alias Ex4pmEngine.Reactors.AutoFdePlannerReactor.PortRegistry

  @impl true
  def run(%{script: script, input: input, request_id: request_id}, _context, options) do
    timeout_ms = Keyword.get(options, :timeout_ms, 5_000)

    port =
      Port.open({:spawn_executable, script}, [:binary, :exit_status, :use_stdio, args: []])

    os_pid =
      case Port.info(port, :os_pid) do
        {:os_pid, pid} -> pid
        _ -> nil
      end

    PortRegistry.put(request_id, port, os_pid)
    Port.command(port, "#{input}\n")

    result = collect(port, "", timeout_ms)

    case result do
      {:ok, output} ->
        PortRegistry.delete(request_id)
        {:ok, String.trim(output)}

      {:error, {:timeout, output}} ->
        {:error, {:script_timeout, timeout_ms, String.trim(output)}}

      {:error, {status, output}} ->
        {:error, {:script_failed, status, String.trim(output)}}
    end
  end

  @impl true
  def compensate(_reason, %{request_id: request_id} = arguments, _context, _options) do
    label = Map.get(arguments, :label, :unknown)

    case PortRegistry.get(request_id) do
      nil ->
        :ok

      {port, os_pid} ->
        outcome =
          if Port.info(port) do
            if os_pid,
              do: System.cmd("kill", ["-TERM", to_string(os_pid)], stderr_to_stdout: true)

            try do
              Port.close(port)
              :closed
            rescue
              ArgumentError -> :already_dead
            end
          else
            :already_dead
          end

        PortRegistry.record_kill(request_id, os_pid, outcome)
        PortRegistry.delete(request_id)

        {:continue, {:failed, label}}
    end
  end

  defp collect(port, acc, timeout_ms) do
    receive do
      {^port, {:data, data}} -> collect(port, acc <> data, timeout_ms)
      {^port, {:exit_status, 0}} -> {:ok, acc}
      {^port, {:exit_status, status}} -> {:error, {status, acc}}
    after
      timeout_ms -> {:error, {:timeout, acc}}
    end
  end
end

defmodule Ex4pmEngine.Reactors.AutoFdePlannerReactor do
  @moduledoc """
  Reference production Reactor workflow demonstrating step compensation,
  process monitoring, and ordered-fallback mechanics.
  """

  use Reactor

  input(:run_id)
  input(:number)
  input(:primary_script)
  input(:fallback_script)

  step :primary_plan, Ex4pmEngine.Reactors.AutoFdePlannerReactor.RunScript do
    argument(:script, input(:primary_script))
    argument(:input, input(:number))
    argument(:request_id, input(:run_id), transform: &(&1 <> "-primary"))
    argument(:label, value(:primary))
    max_retries(0)
  end

  step :fallback_plan, Ex4pmEngine.Reactors.AutoFdePlannerReactor.RunScript do
    argument(:script, input(:fallback_script))
    argument(:input, input(:number))
    argument(:request_id, input(:run_id), transform: &(&1 <> "-fallback"))
    argument(:label, value(:fallback))
    argument(:primary_result, result(:primary_plan))
    where(&__MODULE__.fallback_needed?/1)
    max_retries(0)
  end

  step :final do
    argument(:primary_result, result(:primary_plan))
    argument(:fallback_result, result(:fallback_plan))

    run(fn
      %{fallback_result: fallback_result}, _ when is_binary(fallback_result) ->
        {:ok, %{source: :fallback, value: fallback_result}}

      %{primary_result: primary_result}, _ when is_binary(primary_result) ->
        {:ok, %{source: :primary, value: primary_result}}

      _args, _ ->
        {:ok, %{source: :none, value: nil}}
    end)
  end

  return(:final)

  @doc false
  def fallback_needed?(%{primary_result: {:failed, _label}}), do: true
  def fallback_needed?(_), do: false
end
