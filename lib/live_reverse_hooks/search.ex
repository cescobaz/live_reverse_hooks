defmodule LiveReverseHooks.Search do
  @moduledoc ~S"""
  Binds a search text to a URL param and a form event.

  On `handle_params` the param goes to an assign. On the search event the
  LiveView patches to the current URL with the new param, and the patch
  sets the assign. Empty strings are assigned as `nil`.

      on_mount LiveReverseHooks.Search
      on_mount {LiveReverseHooks.Search, key: :tag_search, search_param: "q", event: "tag_search"}

  It can be listed more than once, each with its own `:key`,
  `:search_param` and `:event`. Mounting one that is already used, also by
  another hook of this library, raises.

  ## On a search change

  When the event changes the search, `c:handle_search_change/3` patches
  to the new URL. By default it drops the `:drop_params_on_change`
  params, e.g. to go back to the first page of a pagination:

      on_mount {LiveReverseHooks.Search, drop_params_on_change: ["page"]}

  To do more, `use LiveReverseHooks.Search` in a module of your own and
  override it. `super/2` does the default patch:

      defmodule MyAppWeb.UserSearch do
        use LiveReverseHooks.Search

        @impl LiveReverseHooks.Search
        def handle_search_change(arg, search, socket),
          do: super(arg, search, assign(socket, :selected, nil))
      end

      on_mount {MyAppWeb.UserSearch, drop_params_on_change: ["page"]}

  ## Options

    * `:key` - the assign with the search text. Defaults to `:search`.
    * `:search_param` - the URL param with the search text. Defaults to
      `"search"`.
    * `:event` - the event that sets the search, `nil` for none. Defaults
      to `"search"`.
    * `:event_search_path` - the event payload path with the text, a key
      or a list of keys for a nested one. Defaults to `"search"`.
    * `:drop_params_on_change` - the URL params removed when the event
      changes the search, e.g. `["page"]`. Defaults to `[]`.
  """
  use LiveReverse
  import Phoenix.LiveView, only: [push_patch: 2]
  alias LiveReverseHooks.{Names, Params}
  alias Phoenix.LiveView.Socket

  @defaults [
    key: :search,
    search_param: "search",
    event: "search",
    event_search_path: "search",
    drop_params_on_change: []
  ]

  @doc """
  Called when the event changes the search to `search`, a text or `nil`.
  It returns the socket, usually patched to the new URL as the default
  implementation does: the patch then assigns `search`. `arg` is the
  `on_mount` argument.
  """
  @callback handle_search_change(
              arg :: :default | keyword,
              search :: String.t() | nil,
              Socket.t()
            ) ::
              Socket.t()

  defmacro __using__(_opts) do
    quote do
      use LiveReverse
      @behaviour LiveReverseHooks.Search

      @impl LiveReverse
      defdelegate mount(arg, params, session, socket), to: LiveReverseHooks.Search

      @impl LiveReverse
      defdelegate unmount(arg, socket), to: LiveReverseHooks.Search

      @impl LiveReverse
      defdelegate handle_params(arg, params, uri, socket), to: LiveReverseHooks.Search

      @impl LiveReverse
      def handle_event(arg, event, payload, socket),
        do: LiveReverseHooks.Search.handle_event(__MODULE__, arg, event, payload, socket)

      @impl LiveReverseHooks.Search
      defdelegate handle_search_change(arg, search, socket), to: LiveReverseHooks.Search

      defoverridable handle_search_change: 3
    end
  end

  @doc """
  Returns the search text of `key` from a socket or assigns, `nil` for
  none.
  """
  def get_search(search, key \\ :search)
  def get_search(%Phoenix.LiveView.Socket{assigns: assigns}, key), do: get_search(assigns, key)
  def get_search(%{} = assigns, key), do: Map.get(assigns, key)

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
  def handle_event(arg, event, payload, socket),
    do: handle_event(__MODULE__, arg, event, payload, socket)

  @doc false
  def handle_event(module, arg, event, payload, socket) do
    opts = opts(arg)

    if event != nil and event == opts[:event] do
      search = payload |> get_in(List.wrap(opts[:event_search_path])) |> empty_to_nil()

      if search == get_search(socket, opts[:key]),
        do: {:halt, socket},
        else: {:halt, module.handle_search_change(arg, search, socket)}
    else
      {:cont, socket}
    end
  end

  @doc """
  The default `c:handle_search_change/3`: patches to the current URL with
  the new search, without the `:drop_params_on_change` params.
  """
  def handle_search_change(arg, search, socket),
    do: push_patch(socket, to: Params.build_to(build_params(arg, search), socket, mode: :merge))

  @doc """
  Returns the params of a search change, the ones the default
  `c:handle_search_change/3` patches to: `search` as the search param,
  and `nil` for each `:drop_params_on_change` param. `arg` is the
  `on_mount` argument.

      Search.build_params([drop_params_on_change: ["page"]], "x")
      #=> %{"page" => nil, "search" => "x"}

  It is not the full query: unlike `LiveReverseHooks.Params.build/3`, it
  leaves out the other params of the URL. Merge it into the current URL
  with `Params.build_to/3` and `mode: :merge`, where a `nil` value
  removes that param:

      Params.build_to(Search.build_params(arg, search), socket, mode: :merge)

  or use it as the starting point of params of your own, e.g. in an
  override of `c:handle_search_change/3`.
  """
  def build_params(arg, search) do
    opts = opts(arg)

    opts[:drop_params_on_change]
    |> Map.new(&{&1, nil})
    |> Map.put(opts[:search_param], search)
  end

  defp names(opts),
    do: [assign: opts[:key], event: opts[:event], param: opts[:search_param]]

  defp opts(:default), do: @defaults
  defp opts(opts) when is_list(opts), do: Keyword.merge(@defaults, opts)

  defp assign_search(socket, key, search), do: assign(socket, key, empty_to_nil(search))

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(search), do: search
end
