defmodule DemoWeb.Words.WordDeleteHook do
  @moduledoc """
  Deletes a word of the user of the `:user_key` assign on the delete
  event; the `Demo.Words` events reload the list (see
  `DemoWeb.Words.WordsHook`).

      on_mount DemoWeb.Words.WordDeleteHook

      <button phx-click="delete" phx-value-id={word.id}>Delete</button>

  ## Options

    * `:user_key` - the assign with the user id. Defaults to `:user_id`.
    * `:event` - the event. Defaults to `"delete"`.
    * `:event_id_path` - the event payload path with the word id, a key
      or a list of keys for a nested one. Defaults to `"id"`.
  """
  use LiveReverse
  alias Demo.Words

  @defaults [user_key: :user_id, event: "delete", event_id_path: "id"]

  @impl true
  def mount(arg, _params, _session, socket) do
    _opts = opts(arg)
    {:cont, socket}
  end

  @impl true
  def handle_event(arg, event, payload, socket) do
    opts = opts(arg)

    if event == opts[:event] do
      with id when is_binary(id) <- get_in(payload, List.wrap(opts[:event_id_path])),
           {id, ""} <- Integer.parse(id) do
        Words.delete(%{user_id: socket.assigns[opts[:user_key]], id: id})
      end

      {:halt, socket}
    else
      {:cont, socket}
    end
  end

  defp opts(:default), do: @defaults
  defp opts(opts) when is_list(opts), do: Keyword.validate!(opts, @defaults)
end
