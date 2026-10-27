defmodule LiveReverseHooks.Search do
  @moduledoc ~S"""
  Binds a search text to a URL param and a form event.

  On `handle_params` the param goes to an assign. On the search event the
  assign is set and the LiveView patches to the current URL with the new
  param. Empty strings are assigned as `nil`.

      on_mount LiveReverseHooks.Search
      on_mount {LiveReverseHooks.Search, key: :tag_search, param: "q", event: "tag_search"}

  ## Options

    * `:key` - the assign with the search text. Defaults to `:search`.
    * `:param` - the URL param. Defaults to `"search"`.
    * `:event` - the event that sets the search. Defaults to `"search"`.
    * `:payload_key` - the payload field with the text. Defaults to `"search"`.
  """
  use LiveReverse
  import Phoenix.LiveView, only: [push_patch: 2]
  alias LiveReverseHooks.Params

  @defaults [key: :search, param: "search", event: "search", payload_key: "search"]

  @doc """
  Returns whether `search` (a socket, assigns or a value) has a search text.
  """
  def search?(search, key \\ :search)
  def search?(%Phoenix.LiveView.Socket{assigns: assigns}, key), do: search?(assigns, key)
  def search?(%{} = assigns, key), do: search?(Map.get(assigns, key), key)
  def search?(search, _key), do: is_binary(search) and search != ""

  @impl true
  def mount(arg, _params, _session, socket) do
    opts = opts(arg)
    {:cont, assign_new(socket, opts[:key], fn -> nil end)}
  end

  @impl true
  def handle_params(arg, params, uri, socket) do
    opts = opts(arg)

    socket =
      socket
      |> Params.put_uri(uri)
      |> assign_search(opts[:key], Map.get(params, opts[:param]))

    {:cont, socket}
  end

  @impl true
  def handle_event(arg, event, payload, socket) do
    opts = opts(arg)

    if event == opts[:event] do
      search = Map.get(payload, opts[:payload_key])

      socket =
        socket
        |> assign_search(opts[:key], search)
        |> push_patch(to: Params.build_to(%{opts[:param] => search}, socket))

      {:halt, socket}
    else
      {:cont, socket}
    end
  end

  defp opts(:default), do: @defaults
  defp opts(opts) when is_list(opts), do: Keyword.merge(@defaults, opts)

  defp assign_search(socket, key, ""), do: assign(socket, key, nil)
  defp assign_search(socket, key, search), do: assign(socket, key, search)
end
