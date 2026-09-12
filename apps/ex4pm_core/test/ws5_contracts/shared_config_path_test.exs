defmodule Ex4pmCore.WS5.SharedConfigPathTest do
  use ExUnit.Case, async: true

  test "core resolves configuration from umbrella root" do
    source = File.read!("apps/ex4pm_core/mix.exs")
    assert source =~ ~s(config_path: "../../config/config.exs")
  end
end
