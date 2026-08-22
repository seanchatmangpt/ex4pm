defmodule Ex4pmWeb.Router do
  use Ex4pmWeb, :router

  import AshAdmin.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {Ex4pmWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api/v1", Ex4pmWeb do
    pipe_through(:api)

    post("/ocel/events", OcelController, :ingest)
  end

  scope "/", Ex4pmWeb do
    pipe_through(:api)

    get("/health", HealthController, :health)
    get("/health/ready", HealthController, :ready)
  end

  scope "/", Ex4pmWeb do
    pipe_through(:browser)

    get("/", HealthController, :health)
    live("/process-intelligence/live", ProcessIntelligenceLive)
    live("/powl-miner", PowlMinerLive)
  end

  scope "/" do
    pipe_through(:browser)

    ash_admin("/admin")
  end
end
