defmodule Mix.Tasks.Ex4pm.Engine.Gen.AdapterTest do
  # Real collaborators: real filesystem and (when present) the real ggen binary.
  use ExUnit.Case, async: false

  alias Mix.Tasks.Ex4pm.Engine.Gen.Adapter

  @pack Path.expand("~/ggen-marketplace/packs/ex4pm-wasm4pm-bindings-pack")

  setup do
    dir = Path.join(System.tmp_dir!(), "gen_adapter_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  test "refuses with REFUSED_NO_CONSUMER when the consumer dir has no ggen.toml", %{dir: dir} do
    err = assert_raise Mix.Error, fn -> Adapter.run(["--dir", dir]) end
    assert Exception.message(err) =~ "REFUSED_NO_CONSUMER"
  end

  @tag skip:
         if(System.find_executable("ggen") && File.dir?(@pack),
           do: false,
           else: "ggen binary or pack not available"
         )
  test "real ggen sync renders the discover leaf from the pack", %{dir: dir} do
    File.ln_s!(Path.join(@pack, "ontology.ttl"), Path.join(dir, "ontology.ttl"))
    File.ln_s!(@pack, Path.join(dir, "pack"))
    File.mkdir_p!(Path.join(dir, "templates"))

    File.write!(Path.join(dir, "ggen.toml"), """
    [project]
    name = "gen-adapter-test"

    [ontology]
    source = "ontology.ttl"

    [packs]
    "ex4pm-wasm4pm-bindings-pack" = { path = "pack" }

    [templates]
    dir = "templates"
    """)

    assert :ok = Adapter.run(["--dir", dir])
    out = File.read!(Path.join(dir, "lib/ex4pm_engine/wasm/discover.ex"))
    assert out =~ "defmodule Ex4pmEngine.Wasm.Discover do"
    assert out =~ "algorithm_id: :discover"
  end
end
