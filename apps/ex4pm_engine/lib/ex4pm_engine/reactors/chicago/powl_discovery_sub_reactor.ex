# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.Chicago.PowlDiscoverySubReactor do
  @moduledoc """
  Composable Sub-Reactor that discovers POWL choice graphs, tests mathematical soundness,
  and compiles interchange representations.
  """
  use Reactor
  alias Ex4pmEngine.Reactors.Chicago.Steps

  input(:traces)

  step :discover_powl, Steps.DiscoverPowlModel do
    argument(:traces, input(:traces))
  end

  step :verify_soundness, Steps.VerifySoundness do
    argument(:model, result(:discover_powl))
  end

  step :export_bpmn do
    argument(:model, result(:discover_powl))

    run(fn %{model: m}, _ctx ->
      xml = Ex4pmEngine.IO.BPMNExporter.to_xml(m)
      {:ok, %{bpmn_xml: xml}}
    end)
  end

  collect :discovery_manifest do
    argument(:model, result(:discover_powl))
    argument(:soundness, result(:verify_soundness))
    argument(:bpmn, result(:export_bpmn))

    transform(fn inputs ->
      %{
        powl_model: inputs.model,
        sound?: inputs.soundness.sound?,
        wf_net: inputs.soundness.wf_net,
        bpmn_xml: inputs.bpmn.bpmn_xml
      }
    end)
  end

  return(:discovery_manifest)
end
