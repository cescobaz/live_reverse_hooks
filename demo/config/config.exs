import Config

config :demo, DemoWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT", "4000"))],
  server: true,
  url: [host: "localhost"],
  # Demo only: never commit a real secret.
  secret_key_base: String.duplicate("demo-secret-key-base-", 4),
  live_view: [signing_salt: "demo-live-view"],
  pubsub_server: Demo.PubSub,
  render_errors: [formats: [html: DemoWeb.ErrorHTML], layout: false]

config :phoenix, :json_library, Jason

config :logger, level: :info
