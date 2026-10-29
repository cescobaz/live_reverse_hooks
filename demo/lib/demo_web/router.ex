defmodule DemoWeb.Router do
  use Phoenix.Router
  import Plug.Conn
  import Phoenix.Controller
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_user_id
    plug :fetch_live_flash
    plug :put_root_layout, html: {DemoWeb.Layouts, :root}
    plug :protect_from_forgery
  end

  scope "/" do
    pipe_through :browser

    live "/", DemoWeb.Words.WordsLive
  end

  # Gives each browser its own user id, kept in the session cookie, so
  # each one gets its own words.
  defp put_user_id(conn, _opts) do
    if get_session(conn, "user_id"),
      do: conn,
      else: put_session(conn, "user_id", Base.url_encode64(:crypto.strong_rand_bytes(12)))
  end
end
