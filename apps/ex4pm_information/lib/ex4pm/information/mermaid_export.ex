defmodule Ex4pm.Information.MermaidExport do
  @moduledoc """
  Renders a production `Ex4pm.Information` Reactor as a Mermaid flowchart via the
  vendored `Reactor.Mermaid` module.

  This is a thin wrapper -- it does not reimplement Mermaid rendering. It exists so
  callers in this app don't have to know the `Reactor.Mermaid` option shape.
  """

  @type reactor_module :: module
  @type options :: Reactor.Mermaid.options()

  @doc """
  Render `reactor` (a Reactor-using module, e.g. `Ex4pm.Information.Flow`) as a
  Mermaid flowchart binary.

  Raises on failure. Delegates directly to `Reactor.Mermaid.to_mermaid!/2`.
  """
  @spec to_mermaid!(reactor_module, options) :: binary
  def to_mermaid!(reactor, options \\ []) when is_atom(reactor) do
    options = Keyword.put_new(options, :output, :binary)

    reactor
    |> Reactor.Mermaid.to_mermaid!(options)
    |> then(fn
      binary when is_binary(binary) -> binary
      iodata -> IO.iodata_to_binary(iodata)
    end)
  end
end
