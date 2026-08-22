defmodule Ex4pm.Evidence.DetsStore do
  @moduledoc "Synchronous DETS receipt ledger candidate for restart-durable local evidence."

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  end

  @impl true
  def init(opts) do
    path = Keyword.fetch!(opts, :path)
    table = Keyword.fetch!(opts, :table)

    case :dets.open_file(table,
           file: String.to_charlist(path),
           type: :set,
           auto_save: :infinity,
           repair: true
         ) do
      {:ok, ^table} -> {:ok, %{table: table, path: path}}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call({:put, %{hash: hash} = receipt}, _from, state) do
    with :ok <- :dets.insert(state.table, {hash, receipt}),
         :ok <- :dets.sync(state.table) do
      {:reply, {:ok, receipt}, state}
    else
      error -> {:reply, {:error, error}, state}
    end
  end

  def handle_call({:get, hash}, _from, state) do
    reply =
      case :dets.lookup(state.table, hash) do
        [{^hash, receipt}] -> {:ok, receipt}
        [] -> :error
      end

    {:reply, reply, state}
  end

  def handle_call(:all, _from, state) do
    receipts =
      :dets.foldl(fn {_hash, receipt}, acc -> [receipt | acc] end, [], state.table)
      |> Enum.sort_by(& &1.started_at)

    {:reply, receipts, state}
  end

  @impl true
  def terminate(_reason, state) do
    :dets.close(state.table)
    :ok
  end
end
