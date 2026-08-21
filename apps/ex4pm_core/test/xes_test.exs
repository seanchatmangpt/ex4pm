defmodule Ex4pm.XESTest do
  use ExUnit.Case, async: true

  alias Ex4pm.XES

  @xes """
  <?xml version="1.0" encoding="UTF-8" ?>
  <log xes.version="1.0" xes.features="nested-attributes">
    <trace>
      <string key="concept:name" value="case-1"/>
      <event>
        <string key="concept:name" value="create"/>
        <date key="time:timestamp" value="2026-01-01T00:00:00Z"/>
      </event>
      <event>
        <string key="concept:name" value="ship"/>
        <date key="time:timestamp" value="2026-01-01T00:01:00Z"/>
      </event>
    </trace>
  </log>
  """

  test "XES becomes the same canonical event-log IR used by OCEL" do
    assert {:ok, log} = XES.parse(@xes)
    assert log.source_format == :xes
    assert map_size(log.objects) == 1
    assert Enum.map(log.events, & &1.activity) == ["create", "ship"]
    assert {:ok, %{"case-1" => events}} = Ex4pm.OCEL.flatten(log, "Case")
    assert Enum.map(events, & &1.activity) == ["create", "ship"]
  end

  test "XES without an activity is refused by canonical admission" do
    invalid = """
    <log><trace><string key="concept:name" value="case-1"/><event><date key="time:timestamp" value="2026-01-01T00:00:00Z"/></event></trace></log>
    """

    assert {:error, %Ex4pm.Refusal{code: :missing_activity}} = XES.parse(invalid)
  end
end
