defmodule LiveReverseHooks.Search do
  @moduledoc ~S"""
  Binds a search text to a URL param and a form event.

  On `handle_params` the param goes to an assign. On the search event the
  assign is set and the LiveView patches to the current URL with the new
  param. Empty strings are assigned as `nil`.

      on_mount LiveReverseHooks.Search
      on_mount {LiveReverseHooks.Search, key: :tag_search, search_param: "q", event: "tag_search"}

  It can be listed more than once, each with its own `:key`,
  `:search_param` and `:event`. Mounting one that is already used, also by
  another hook of this library, raises.

  ## Options

    * `:key` - the assign with the search text. Defaults to `:search`.
    * `:search_param` - the URL param with the search text. Defaults to
      `"search"`.
    * `:event` - the event that sets the search, `nil` for none. Defaults
      to `"search"`.
    * `:event_search_path` - the event payload path with the text, a key
      or a list of keys for a nested one. Defaults to `"search"`.
  """
  use LiveReverse
  import Phoenix.LiveView, only: [push_patch: 2]
  alias LiveReverseHooks.{Names, Params}

  @defaults [key: :search, search_param: "search", event: "search", event_search_path: "search"]

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

    Names.validate_opts!(opts, @defaults, "search")

    socket =
      socket
      |> Names.claim!(names(opts))
      |> assign_new(opts[:key], fn -> nil end)

    {:cont, socket}
  end

  @impl true
  def unmount(arg, socket), do: Names.release(socket, names(opts(arg)))

  @impl true
  def handle_params(arg, params, uri, socket) do
    opts = opts(arg)

    socket =
      socket
      |> Params.put_uri(uri)
      |> assign_search(opts[:key], Map.get(params, opts[:search_param]))

    {:cont, socket}
  end

  @impl true
  def handle_event(arg, event, payload, socket) do
    opts = opts(arg)

    if event != nil and event == opts[:event] do
      search = get_in(payload, List.wrap(opts[:event_search_path]))

      socket =
        socket
        |> assign_search(opts[:key], search)
        |> push_patch(to: Params.build_to(%{opts[:search_param] => search}, socket, mode: :merge))

      {:halt, socket}
    else
      {:cont, socket}
    end
  end

  defp names(opts),
    do: [assign: opts[:key], event: opts[:event], param: opts[:search_param]]

  defp opts(:default), do: @defaults
  defp opts(opts) when is_list(opts), do: Keyword.merge(@defaults, opts)

  defp assign_search(socket, key, ""), do: assign(socket, key, nil)
  defp assign_search(socket, key, search), do: assign(socket, key, search)
end
