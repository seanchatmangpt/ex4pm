defmodule Ex4pmEngine.Wasm.Host do
  @moduledoc """
  Supervised owner of the real Wasmex instance for the wasm4pm bindings
  artifact.

  Artifact path precedence: start opt `:artifact_path`, Application env
  `:ex4pm, :wasm4pm_artifact`, env `EX4PM_WASM_ARTIFACT`, then the bundled
  `priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm`.

  Admission (`Ex4pmEngine.Wasm.Admission`) and boot run in `handle_continue`;
  a missing or unadmitted artifact leaves the Host alive with a typed
  `%Ex4pm.Refusal{}` (see `status/0`, `transports/0`) and never fails app boot.
  The instance is linked to (and rebuilt by) the Host on exit or trap, and
  transport closures re-resolve the live instance on every call.
  """
  use GenServer

  alias Ex4pm.Refusal
  alias Ex4pmEngine.Wasm.RealTransport

  @name __MODULE__

  # -- API ----------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, @name))
  end

  @doc "Artifact path resolved by the documented precedence."
  def artifact_path(opts \\ []) do
    Keyword.get(opts, :artifact_path) ||
      Application.get_env(:ex4pm, :wasm4pm_artifact) ||
      nonempty(System.get_env("EX4PM_WASM_ARTIFACT")) ||
      Application.app_dir(:ex4pm, "priv/wasm4pm/wasm4pm_ex4pm_bindings.wasm")
  end

  @spec status(GenServer.server()) :: map()
  def status(server \\ @name), do: GenServer.call(server, :status, 60_000)

  @doc "All `<algo>_wasm_fun` closures, or a typed refusal."
  @spec transports(GenServer.server()) :: {:ok, keyword()} | {:error, Refusal.t()}
  def transports(server \\ @name) do
    case safe_status(server) do
      %{admitted: true} ->
        {:ok, Enum.map(RealTransport.algo_specs(), &{key(&1), closure(server, &1)})}

      %{refusal: %Refusal{} = r} ->
        {:error, r}

      _ ->
        {:error, Refusal.new(:wasm_host_unavailable, "wasm host is not running")}
    end
  end

  @doc "Alias of `transports/0`."
  def transport_opts(server \\ @name), do: transports(server)

  @doc "Transport closure for `key` (e.g. `:discover_wasm_fun`) when running and admitted, else nil."
  def transport(key, server \\ @name) do
    with %{admitted: true} <- safe_status(server),
         spec when not is_nil(spec) <- Enum.find(RealTransport.algo_specs(), &(key(&1) == key)) do
      closure(server, spec)
    else
      _ -> nil
    end
  end

  @doc "Re-resolves the live instance, rebuilding it if dead."
  def instance(server \\ @name) do
    GenServer.call(server, :instance, 60_000)
  catch
    :exit, _ -> {:error, Refusal.new(:wasm_host_unavailable, "wasm host is not running")}
  end

  @doc false
  def rebuild(server, pid), do: GenServer.call(server, {:rebuild, pid}, 60_000)

  # -- closures -------------------------------------------------------------

  defp key(spec), do: :"#{spec.algorithm_id}_wasm_fun"

  defp closure(server, spec) do
    tspec = %{
      export_name: spec.export_name,
      replay_export_name: spec.replay_export_name,
      algorithm_id: spec.algorithm_id,
      protocol: Ex4pmEngine.Wasm.Adapter.protocol(),
      wasm4pm_source_sha: Ex4pmEngine.Wasm.Adapter.wasm4pm_source_sha()
    }

    fn request, opts -> invoke(server, tspec, request, opts, 1) end
  end

  defp invoke(server, tspec, request, opts, retries) do
    case instance(server) do
      {:ok, inst} ->
        result = RealTransport.default_transport(inst, tspec).(request, opts)

        case result do
          {:error, %Refusal{code: code}}
          when code in [:call_trapped, :abi_failure] and retries > 0 ->
            _ = safe_rebuild(server, inst.pid)
            invoke(server, tspec, request, opts, retries - 1)

          other ->
            other
        end

      {:error, _} = err ->
        err
    end
  end

  defp safe_rebuild(server, pid) do
    rebuild(server, pid)
  catch
    :exit, _ -> :error
  end

  defp safe_status(server) do
    status(server)
  catch
    :exit, _ -> nil
  end

  # -- server ---------------------------------------------------------------

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    {:ok,
     %{
       opts: opts,
       path: artifact_path(opts),
       sha256: nil,
       instance: nil,
       refusal: nil,
       restarts: 0
     }, {:continue, :boot}}
  end

  @impl true
  def handle_continue(:boot, state), do: {:noreply, boot(state)}

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, status_map(state), state}
  end

  def handle_call(:instance, _from, state) do
    state = ensure_alive(state)

    case state.instance do
      %{} = inst -> {:reply, {:ok, inst}, state}
      nil -> {:reply, {:error, state.refusal || unavailable()}, state}
    end
  end

  def handle_call({:rebuild, pid}, _from, state) do
    state =
      case state.instance do
        %{pid: ^pid} -> state |> drop_instance() |> boot() |> bump()
        _ -> ensure_alive(state)
      end

    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:EXIT, pid, _reason}, %{instance: %{pid: pid}} = state) do
    {:noreply, state |> Map.put(:instance, nil) |> boot() |> bump()}
  end

  def handle_info({:EXIT, _pid, _reason}, state), do: {:noreply, state}
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    drop_instance(state)
    :ok
  end

  # -- internals -------------------------------------------------------------

  defp ensure_alive(%{instance: %{pid: pid}} = state) do
    if Process.alive?(pid), do: state, else: state |> Map.put(:instance, nil) |> boot() |> bump()
  end

  defp ensure_alive(%{instance: nil, refusal: nil} = state), do: boot(state)
  defp ensure_alive(state), do: state

  defp bump(%{instance: %{}} = state), do: %{state | restarts: state.restarts + 1}
  defp bump(state), do: state

  defp drop_instance(%{instance: %{pid: pid}} = state) do
    Process.unlink(pid)
    if Process.alive?(pid), do: Process.exit(pid, :kill)
    %{state | instance: nil}
  end

  defp drop_instance(state), do: state

  defp boot(state) do
    start_opts =
      Keyword.take(state.opts, [:expected_sha256, :import_allowlist, :required_exports])

    result =
      try do
        RealTransport.start(state.path, start_opts)
      catch
        kind, reason ->
          {:error,
           Refusal.new(:wasm_host_boot_failed, "wasm host boot failed",
             details: %{error: inspect({kind, reason})}
           )}
      end

    case result do
      {:ok, inst} ->
        %{state | instance: inst, sha256: inst.artifact_hash, refusal: nil}

      {:error, %Refusal{} = r} ->
        %{state | instance: nil, refusal: r, sha256: file_sha(state.path)}

      {:error, posix} when is_atom(posix) ->
        r =
          Refusal.new(:wasm_artifact_missing, "wasm artifact cannot be read",
            details: %{path: state.path, reason: inspect(posix)}
          )

        %{state | instance: nil, refusal: r, sha256: nil}

      {:error, other} ->
        r =
          Refusal.new(:wasm_host_boot_failed, "wasm host boot failed",
            details: %{reason: inspect(other)}
          )

        %{state | instance: nil, refusal: r}
    end
  end

  defp status_map(state) do
    %{
      artifact_path: state.path,
      sha256: state.sha256,
      admitted: match?(%{}, state.instance),
      alive:
        match?(%{pid: pid} when is_pid(pid), state.instance) and
          Process.alive?(state.instance.pid),
      restarts: state.restarts,
      refusal: state.refusal
    }
  end

  defp file_sha(path) do
    case File.read(path) do
      {:ok, bytes} -> :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
      _ -> nil
    end
  end

  defp unavailable, do: Refusal.new(:wasm_host_unavailable, "wasm instance unavailable")

  defp nonempty(v) when is_binary(v) and v != "", do: v
  defp nonempty(_), do: nil
end
