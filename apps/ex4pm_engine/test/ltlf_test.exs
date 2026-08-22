defmodule Ex4pm.Engine.LtlfTest do
  use ExUnit.Case, async: true

  alias Ex4pmEngine.LTLf

  test "verifies response, precedence, and non-coexistence LTLf constraints" do
    # Trace 1: Valid trace satisfying Response(request, deploy) and Precedence(security_scan, deploy)
    trace_valid = ["request", "security_scan", "deploy"]

    formulas = [
      {:response, "request", "deploy"},
      {:precedence, "security_scan", "deploy"},
      {:non_coexistence, "deploy", "rollback"}
    ]

    report = LTLf.evaluate_trace(trace_valid, formulas)
    assert report.satisfied? == true
    assert report.violations_count == 0

    # Trace 2: Violates precedence (deploy before security_scan) and response (request with no deploy)
    trace_invalid = ["deploy", "request", "rollback"]

    report_bad = LTLf.evaluate_trace(trace_invalid, formulas)
    assert report_bad.satisfied? == false
    assert report_bad.violations_count >= 2
  end

  test "verifies chain-response and exactly-once temporal rules" do
    trace = ["login", "2fa_verify", "dashboard"]

    formulas = [
      {:chain_response, "login", "2fa_verify"},
      {:exactly_once, "login"},
      {:absence, "unauthorized_access"}
    ]

    report = LTLf.evaluate_trace(trace, formulas)
    assert report.satisfied? == true
  end
end
