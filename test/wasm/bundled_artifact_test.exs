defmodule Ex4pmEngine.Wasm.BundledArtifactTest do
  @moduledoc """
  Always-on court for the wasm artifact bundled in `priv/wasm4pm`. Never skipped:
  the package ships its own subject, so absence is a failure. Real file, real
  section parser, real Wasmtime admission -- no doubles.
  """
  use ExUnit.Case, async: true
  import Bitwise

  alias Ex4pmEngine.Wasm.Admission

  @dir Application.app_dir(:ex4pm, "priv/wasm4pm")
  @wasm Path.join(@dir, "wasm4pm_ex4pm_bindings.wasm")
  @manifest Path.join(@dir, "MANIFEST.json")

  @core ~w(wasm4pm_ex4pm_bindings_alloc_v1 wasm4pm_ex4pm_bindings_dealloc_v1
           wasm4pm_ex4pm_bindings_free_v1 wasm4pm_ex4pm_bindings_version_v1)

  setup_all do
    {:ok, bytes: File.read!(@wasm), manifest: @manifest |> File.read!() |> Jason.decode!()}
  end

  test "bundled artifact exists and matches manifest sha256 and size", %{
    bytes: bytes,
    manifest: m
  } do
    assert File.regular?(@wasm)
    assert m["artifact"]["path"] == "wasm4pm_ex4pm_bindings.wasm"
    assert :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower) == m["artifact"]["sha256"]
    assert byte_size(bytes) == m["artifact"]["size"]
    assert m["artifact"]["sha256"] == Admission.manifest_sha256()
  end

  test "zero imports and exactly 4 core + 66 algo function exports", %{bytes: bytes, manifest: m} do
    {imports, exports} = parse(bytes)
    assert imports == 0
    assert m["provenance"]["import_count"] == 0

    funcs = for {name, 0} <- exports, do: name
    assert [{"memory", 2}] == Enum.filter(exports, fn {_, kind} -> kind != 0 end)
    assert length(funcs) == 70
    assert m["provenance"]["export_count"] == 70
    assert @core -- funcs == []

    algo = funcs -- @core
    assert length(algo) == 66
    assert Enum.all?(algo, &String.match?(&1, ~r/^wasm4pm_ex4pm_[a-z0-9_]+_v1$/))
    assert length(Enum.filter(algo, &String.ends_with?(&1, "_replay_v1"))) == 33
  end

  test "bundled artifact admits through Admission", %{bytes: bytes} do
    assert {:ok, %{sha256: sha}} =
             Admission.admit(bytes, expected_sha256: Admission.manifest_sha256())

    assert sha == "sha256:" <> Admission.manifest_sha256()
  end

  # -- minimal wasm section parser: {import_count, [{export_name, kind}]} ---------

  defp parse(<<0, "asm", 1, 0, 0, 0, rest::binary>>), do: sections(rest, {0, []})

  defp sections(<<>>, {i, e}), do: {i, Enum.reverse(e)}

  defp sections(<<id, rest::binary>>, acc) do
    {size, rest} = leb(rest)
    <<body::binary-size(size), rest::binary>> = rest
    sections(rest, section(id, body, acc))
  end

  defp section(2, body, {_, e}), do: {elem(leb(body), 0), e}

  defp section(7, body, {i, _}) do
    {n, rest} = leb(body)
    {i, read_exports(n, rest, [])}
  end

  defp section(_, _, acc), do: acc

  defp read_exports(0, _, acc), do: acc

  defp read_exports(n, rest, acc) do
    {len, rest} = leb(rest)
    <<name::binary-size(len), kind, rest::binary>> = rest
    {_idx, rest} = leb(rest)
    read_exports(n - 1, rest, [{name, kind} | acc])
  end

  defp leb(bin), do: leb(bin, 0, 0)

  defp leb(<<1::1, v::7, rest::binary>>, acc, shift),
    do: leb(rest, acc ||| v <<< shift, shift + 7)

  defp leb(<<0::1, v::7, rest::binary>>, acc, shift), do: {acc ||| v <<< shift, rest}
end
