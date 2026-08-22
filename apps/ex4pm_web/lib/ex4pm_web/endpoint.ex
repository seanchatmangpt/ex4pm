defmodule Ex4pmWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :ex4pm_web

  @session_options [
    store: :cookie,
    key: "_ex4pm_control_plane_key",
    signing_salt: "control_plane_salt_123"
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  plug(Plug.Static,
    at: "/",
    from: :ex4pm_web,
    gzip: false,
    only: Ex4pmWeb.static_paths()
  )

  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(Ex4pmWeb.Router)
end
