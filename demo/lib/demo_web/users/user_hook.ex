defmodule DemoWeb.Users.UserHook do
  @moduledoc """
  Assigns the user id of the session, put there by the router (see
  `DemoWeb.Router`). Mount it first, so the other hooks find it.

      on_mount DemoWeb.Users.UserHook

  ## Options

    * `:key` - the assign with the user id. Defaults to `:user_id`.
    * `:session_key` - the session key with the user id. Defaults to
      `"user_id"`.
  """
  use LiveReverse

  @defaults [key: :user_id, session_key: "user_id"]

  @impl true
  def mount(arg, _params, session, socket) do
    opts = opts(arg)
    {:cont, assign(socket, opts[:key], Map.fetch!(session, opts[:session_key]))}
  end

  defp opts(:default), do: @defaults
  defp opts(opts) when is_list(opts), do: Keyword.validate!(opts, @defaults)
end
