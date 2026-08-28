defmodule Ex4pmCore.WS5.SweetXmlDependencyBandTest do
  use ExUnit.Case, async: true

  test "canonical core remains on SweetXml 0.7.5 compatibility band" do
    source = File.read!("apps/ex4pm_core/mix.exs")
    assert source =~ ~s({:sweet_xml, "~> 0.7.5"})
  end
end
