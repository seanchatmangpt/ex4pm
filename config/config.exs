import Config

config :logger, level: :info

config :ex4pm_domain, ash_domains: [Ex4pm.Domain, Ex4pmDomain]
config :ash_admin, domains: [Ex4pm.Domain, Ex4pmDomain]

config :ex4pm, :pubsub, Ex4pm.PubSub

config :ex4pm_web, Ex4pmWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [formats: [html: Ex4pmWeb.ErrorHTML, json: Ex4pmWeb.ErrorJSON], layout: false],
  pubsub_server: Ex4pmWeb.PubSub,
  live_view: [signing_salt: "ex4pm_secret_salt_control_plane_1234567890"],
  secret_key_base:
    "ex4pm_super_secret_key_base_for_live_process_intelligence_control_plane_64byteslong"

if Mix.env() == :test do
  config :logger, level: :warning

  config :ex4pm_runtime, Ex4pmRuntime.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: 4002],
    server: false

  config :ex4pm_web, Ex4pmWeb.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: 4003],
    server: false
end
