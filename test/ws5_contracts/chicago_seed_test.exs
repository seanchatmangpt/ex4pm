defmodule Ex4pmCore.WS5.ChicagoSeedTest do
  use ExUnit.Case, async: true
  @manifest File.read!(Path.expand("../../../../mix.exs", __DIR__))

  test "chicago qualification remains deterministically seeded" do
    assert @manifest =~ ~s(chicago: ["do --app ex4pm test --only chicago --seed 0"])
  end
end
