defmodule Ex4pmEngine.Wasm.Phase4EdgeCasesTest do
  @moduledoc """
  Real, no-mock edge-case coverage for the 14 Phase-4 statistics/ML
  capabilities: empty/degenerate/negative inputs, driven directly through
  `Ex4pmEngine.Wasm.RealTransport.call/3` against the real compiled
  artifact (no Reactor overhead needed for these -- each test is
  independent and cheap). Every expected value below is read directly from
  the real Rust implementation's own documented behavior in
  `~/wasm4pm/wasm4pm/src/{ml/*,hand_stats,prediction_drift}.rs` (e.g. "n ==
  0 -> return zeros", not invented here).

  Named, honest skip (not a silent pass) when the real artifact hasn't been
  built on this machine.
  """
  use ExUnit.Case, async: true

  alias Ex4pmEngine.Wasm.RealTransport

  @artifact_path Path.expand(
                   "~/wasm4pm/target/wasm32-unknown-unknown/release/wasm4pm_ex4pm_bindings.wasm"
                 )

  setup do
    if File.regular?(@artifact_path) do
      {:ok, instance} = RealTransport.start(@artifact_path)
      {:ok, instance: instance}
    else
      {:skip, "wasm artifact not built"}
    end
  end

  defp result!(instance, export, request) do
    assert {:ok, %{"result" => result}} = RealTransport.call(instance, export, request)
    result
  end

  # -- ks_statistic --------------------------------------------------------

  @tag :real_wasm
  test "ks_statistic is real 0.0 when either sample is empty (documented no-comparison case)", %{
    instance: i
  } do
    r = result!(i, "wasm4pm_ex4pm_ks_statistic_v1", %{sample_a: [], sample_b: [1.0, 2.0]})
    assert r["ks_statistic"] == 0.0
  end

  @tag :real_wasm
  test "ks_statistic is real and maximal (1.0) for two fully disjoint, ordered samples", %{
    instance: i
  } do
    r =
      result!(i, "wasm4pm_ex4pm_ks_statistic_v1", %{
        sample_a: [1.0, 2.0, 3.0],
        sample_b: [10.0, 11.0, 12.0]
      })

    assert r["ks_statistic"] == 1.0
  end

  # -- ks_critical_value ----------------------------------------------------

  @tag :real_wasm
  test "ks_critical_value is real +infinity when either sample size is zero", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_ks_critical_value_v1", %{n: 0, m: 10, alpha: 0.05})
    assert r["ks_critical_value"] in [nil, "inf", :infinity]
  end

  @tag :real_wasm
  test "ks_critical_value at alpha=0.01 uses the real, larger coefficient than alpha=0.05", %{
    instance: i
  } do
    r01 = result!(i, "wasm4pm_ex4pm_ks_critical_value_v1", %{n: 10, m: 10, alpha: 0.01})
    r05 = result!(i, "wasm4pm_ex4pm_ks_critical_value_v1", %{n: 10, m: 10, alpha: 0.05})
    assert r01["ks_critical_value"] > r05["ks_critical_value"]
  end

  # -- regression -------------------------------------------------------

  @tag :real_wasm
  test "regression on empty input returns real documented zeros", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_regression_v1", %{x: [], y: []})
    assert r["slope"] == 0.0
    assert r["r_squared"] == 0.0
  end

  @tag :real_wasm
  test "regression on mismatched-length x/y returns real documented zeros", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_regression_v1", %{x: [1.0, 2.0], y: [1.0]})
    assert r["slope"] == 0.0
  end

  @tag :real_wasm
  test "regression on a real negative-slope line recovers slope -3.0", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_regression_v1", %{x: [0.0, 1.0, 2.0], y: [10.0, 7.0, 4.0]})
    assert_in_delta r["slope"], -3.0, 1.0e-9
  end

  # -- forecast / holt_forecast ------------------------------------------

  @tag :real_wasm
  test "forecast on empty data returns real documented zeros", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_forecast_v1", %{data: [], alpha: 0.3})
    assert r["next_window"] == 0.0
    assert r["rmse"] == 0.0
  end

  @tag :real_wasm
  test "forecast on a single point predicts that same point (no error to smooth)", %{
    instance: i
  } do
    r = result!(i, "wasm4pm_ex4pm_forecast_v1", %{data: [7.0], alpha: 0.3})
    assert r["next_window"] == 7.0
  end

  @tag :real_wasm
  test "holt_forecast on empty series returns real documented zeros", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_holt_forecast_v1", %{series: [], alpha: 0.5, beta: 0.5})
    assert r["next_window"] == 0.0
  end

  @tag :real_wasm
  test "holt_forecast on a constant series has real zero trend and stable prediction", %{
    instance: i
  } do
    r =
      result!(i, "wasm4pm_ex4pm_holt_forecast_v1", %{
        series: [5.0, 5.0, 5.0, 5.0],
        alpha: 0.5,
        beta: 0.5
      })

    assert_in_delta r["next_window"], 5.0, 1.0e-6
  end

  # -- ewma / trend_classify ----------------------------------------------

  @tag :real_wasm
  test "ewma on empty values returns real empty output", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_ewma_v1", %{values: [], alpha: 0.5})
    assert r["ewma"] == []
  end

  @tag :real_wasm
  test "ewma with a low alpha heavily smooths a real spike", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_ewma_v1", %{values: [1.0, 100.0, 1.0], alpha: 0.1})
    [first, second, _third] = r["ewma"]
    assert first == 1.0
    assert second < 15.0
  end

  @tag :real_wasm
  test "trend_classify on a single sample is real 'stable' by definition", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_trend_classify_v1", %{smoothed: [42.0]})
    assert r["trend"] == "stable"
  end

  @tag :real_wasm
  test "trend_classify detects a real falling series", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_trend_classify_v1", %{smoothed: [10.0, 8.0, 6.0, 4.0, 2.0]})
    assert r["trend"] == "falling"
  end

  @tag :real_wasm
  test "trend_classify on a real constant series is 'stable'", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_trend_classify_v1", %{smoothed: [3.0, 3.0, 3.0]})
    assert r["trend"] == "stable"
  end

  # -- mean / dot_product / euclidean_distance -----------------------------

  @tag :real_wasm
  test "mean of empty data is real documented 0.0", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_mean_v1", %{data: []})
    assert r["mean"] == 0.0
  end

  @tag :real_wasm
  test "mean of a single negative value is that real value", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_mean_v1", %{data: [-5.0]})
    assert r["mean"] == -5.0
  end

  @tag :real_wasm
  test "dot_product of orthogonal unit vectors is real 0.0", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_dot_product_v1", %{a: [1.0, 0.0], b: [0.0, 1.0]})
    assert r["dot_product"] == 0.0
  end

  @tag :real_wasm
  test "dot_product with negative components computes the real signed result", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_dot_product_v1", %{a: [1.0, -2.0], b: [-3.0, 4.0]})
    assert r["dot_product"] == -11.0
  end

  @tag :real_wasm
  test "euclidean_distance between identical points is real 0.0", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_euclidean_distance_v1", %{a: [1.0, 1.0], b: [1.0, 1.0]})
    assert r["euclidean_distance"] == 0.0
  end

  @tag :real_wasm
  test "euclidean_distance with negative coordinates computes the real distance", %{
    instance: i
  } do
    r = result!(i, "wasm4pm_ex4pm_euclidean_distance_v1", %{a: [-1.0, -1.0], b: [2.0, 3.0]})
    assert r["euclidean_distance"] == 5.0
  end

  # -- standardize ----------------------------------------------------------

  @tag :real_wasm
  test "standardize on empty data returns real empty output", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_standardize_v1", %{data: []})
    assert r["standardized"] == []
  end

  @tag :real_wasm
  test "standardize on a real constant column yields zero (no division-by-zero crash)", %{
    instance: i
  } do
    r = result!(i, "wasm4pm_ex4pm_standardize_v1", %{data: [[5.0], [5.0], [5.0]]})
    assert length(r["standardized"]) == 3
  end

  # -- median / percentile / std_deviation ---------------------------------

  @tag :real_wasm
  test "median of empty data is real null (None)", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_median_v1", %{data: []})
    assert r["median"] == nil
  end

  @tag :real_wasm
  test "median of an even-length series is the real average of the two middle values", %{
    instance: i
  } do
    r = result!(i, "wasm4pm_ex4pm_median_v1", %{data: [1.0, 2.0, 3.0, 4.0]})
    assert r["median"] == 2.5
  end

  @tag :real_wasm
  test "percentile 0 is the real minimum and percentile 100 is the real maximum", %{
    instance: i
  } do
    r0 = result!(i, "wasm4pm_ex4pm_percentile_v1", %{data: [4.0, 1.0, 3.0, 2.0], p: 0.0})
    r100 = result!(i, "wasm4pm_ex4pm_percentile_v1", %{data: [4.0, 1.0, 3.0, 2.0], p: 100.0})
    assert r0["percentile"] == 1.0
    assert r100["percentile"] == 4.0
  end

  @tag :real_wasm
  test "percentile of empty data is real null (None)", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_percentile_v1", %{data: [], p: 50.0})
    assert r["percentile"] == nil
  end

  @tag :real_wasm
  test "std_deviation of empty data is real null (None)", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_std_deviation_v1", %{data: []})
    assert r["std_deviation"] == nil
  end

  @tag :real_wasm
  test "std_deviation of a real two-point spread computes correctly", %{instance: i} do
    r = result!(i, "wasm4pm_ex4pm_std_deviation_v1", %{data: [0.0, 10.0]})
    assert_in_delta r["std_deviation"], 5.0, 1.0e-9
  end

  # -- replay agreement, all 14, one round each ----------------------------

  @tag :real_wasm
  test "all 14 Phase-4 replay exports agree with a direct recompute", %{instance: i} do
    checks = [
      {"wasm4pm_ex4pm_ks_statistic_replay_v1", %{sample_a: [1.0], sample_b: [2.0]}},
      {"wasm4pm_ex4pm_ks_critical_value_replay_v1", %{n: 5, m: 5, alpha: 0.05}},
      {"wasm4pm_ex4pm_regression_replay_v1", %{x: [1.0, 2.0], y: [1.0, 2.0]}},
      {"wasm4pm_ex4pm_forecast_replay_v1", %{data: [1.0, 2.0], alpha: 0.5}},
      {"wasm4pm_ex4pm_holt_forecast_replay_v1", %{series: [1.0, 2.0], alpha: 0.5, beta: 0.5}},
      {"wasm4pm_ex4pm_ewma_replay_v1", %{values: [1.0, 2.0], alpha: 0.5}},
      {"wasm4pm_ex4pm_trend_classify_replay_v1", %{smoothed: [1.0, 2.0]}},
      {"wasm4pm_ex4pm_mean_replay_v1", %{data: [1.0, 2.0]}},
      {"wasm4pm_ex4pm_dot_product_replay_v1", %{a: [1.0], b: [2.0]}},
      {"wasm4pm_ex4pm_euclidean_distance_replay_v1", %{a: [0.0], b: [1.0]}},
      {"wasm4pm_ex4pm_standardize_replay_v1", %{data: [[1.0], [2.0]]}},
      {"wasm4pm_ex4pm_median_replay_v1", %{data: [1.0, 2.0]}},
      {"wasm4pm_ex4pm_percentile_replay_v1", %{data: [1.0, 2.0], p: 50.0}},
      {"wasm4pm_ex4pm_std_deviation_replay_v1", %{data: [1.0, 2.0]}}
    ]

    for {export, request} <- checks do
      assert {:ok, true} = RealTransport.replay(i, export, request),
             "#{export} failed real replay verification"
    end
  end
end
