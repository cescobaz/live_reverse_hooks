defmodule DemoWeb.Words.WordResetHook do
  @moduledoc """
  Resets the words of the user of the `:user_key` assign to the preset
  ones on the reset event; the `Demo.Words` events reload the list (see
  `DemoWeb.Words.WordsHook`).

      on_mount DemoWeb.Words.WordResetHook

      <button phx-click="reset">Reset words</button>

  ## Options

    * `:user_key` - the assign with the user id. Defaults to `:user_id`.
    * `:event` - the event. Defaults to `"reset"`.
  """
  use LiveReverse
  alias Demo.Words

  @defaults [user_key: :user_id, event: "reset"]

  @impl true
  def mount(arg, _params, _session, socket) do
    _opts = opts(arg)
    {:cont, socket}
  end

  @impl true
  def handle_event(arg, event, _payload, socket) do
    opts = opts(arg)

    if event == opts[:event] do
      :ok = Words.reset_user(socket.assigns[opts[:user_key]])
      {:halt, socket}
    else
      {:cont, socket}
    end
  end

  defp opts(:default), do: @defaults
  defp opts(opts) when is_list(opts), do: Keyword.validate!(opts, @defaults)
end
