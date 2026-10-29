defmodule DemoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :demo

  @session_options [
    store: :cookie,
    key: "_demo_key",
    signing_salt: "demo-session",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  # The JS clients straight from the deps, no asset build.
  plug Plug.Static, at: "/assets/phoenix", from: {:phoenix, "priv/static"}, only: ~w(phoenix.mjs)

  plug Plug.Static,
    at: "/assets/phoenix_live_view",
    from: {:phoenix_live_view, "priv/static"},
    only: ~w(phoenix_live_view.esm.js)

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.Parsers, parsers: [:urlencoded], pass: ["*/*"]
  plug Plug.Session, @session_options
  plug DemoWeb.Router
end
