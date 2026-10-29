defmodule LiveReverseHooks.Pagination do
  @moduledoc ~S"""
  Binds the current page to a URL param.

  On `handle_params` the page and its size are assigned to `:key` as
  `%{page: page, size: size}`, so a change of either renders. A missing,
  invalid or less than 1 page is `1`; the size comes from the
  `:page_size_param` param, or `:page_size` without one.

      on_mount LiveReverseHooks.Pagination
      on_mount {LiveReverseHooks.Pagination, key: :page, page_param: "p", page_size: 20}

  `get_offset/3` and `get_limit/3` turn the page into a query window, and
  `page_to/3` and `page_rel_to/3` build the path to patch to:

      items = Items.list(offset: Pagination.get_offset(socket), limit: Pagination.get_limit(socket))

      push_patch(socket, to: Pagination.page_rel_to(socket, 1))

  ## Several paginations

  It can be listed more than once, e.g. one per panel, each with its own
  `:key`, `:page_param`, `:page_size_param` and `:event`; mounting one that is
  already used, also by another hook of this library, raises. The functions take the `:key` of the pagination
  to use, `:page` by default:

      on_mount {LiveReverseHooks.Pagination, key: :users_page, page_param: "users_page"}
      on_mount {LiveReverseHooks.Pagination, key: :groups_page, page_param: "groups_page", page_size: 10}

      Pagination.get_offset(socket, :groups_page)
      Pagination.page_rel_to(socket, :users_page, 1)

  ## Events

  The `:event` event patches to a page. Its payload has the
  absolute page at `:event_page_path`, a page relative to the current one
  at `:event_rel_path`, or a page size (see `page_size_to/3`) at
  `:event_size_path`:

      on_mount {LiveReverseHooks.Pagination, key: :users_page, page_param: "up", event: "users_page"}

      <button phx-click="users_page" phx-value-rel="-1">Previous</button>
      <button phx-click="users_page" phx-value-page="1">First</button>

  A path is a payload key, or a list of keys for a nested one. The values
  are integers or strings of one; a payload without a valid one is
  ignored.

  ## Options

    * `:key` - the assign with the page and size, also naming the
      pagination.
      Defaults to `:page`.
    * `:page_param` - the URL param with the page. Defaults to `"page"`.
    * `:page_size` - the page size, `nil` for none. Defaults to `20`.
    * `:page_size_param` - the URL param with the page size, e.g.
      `"users_page_size"`. A missing or invalid one falls back to
      `:page_size`. Defaults to `nil`, a fixed page size.
    * `:event` - the event that sets the page, `nil` for none. Defaults to
      `"page"`.
    * `:event_page_path` - the event payload path with an absolute page. Defaults to
      `"page"`.
    * `:event_rel_path` - the event payload path with a relative page. Defaults to
      `"rel"`.
    * `:event_size_path` - the event payload path with a page size. Defaults to
      `"size"`.
  """
  use LiveReverse
  import Phoenix.LiveView, only: [push_patch: 2, put_private: 3]
  alias LiveReverseHooks.{Names, Params}

  @defaults [
    key: :page,
    page_param: "page",
    page_size: 20,
    page_size_param: nil,
    event: "page",
    event_page_path: "page",
    event_rel_path: "rel",
    event_size_path: "size"
  ]

  @doc """
  Returns the current page of the `key` pagination, starting at `1`.
  """
  def get_page(socket, key \\ :page), do: pagination!(socket, key).page

  @doc """
  Returns the page size of the `key` pagination. Raises if it was mounted
  with `page_size: nil` and the `:page_size_param` param is not set.
  """
  def get_page_size(socket, key \\ :page) do
    case pagination!(socket, key).size do
      nil ->
        raise ArgumentError,
              "no page size for pagination #{inspect(key)}, mounted with page_size: nil"

      size ->
        size
    end
  end

  @doc """
  Returns the offset of the current page of the `key` pagination, with
  `size` or its page size. With an integer second argument, it is the
  `size` of the `:page` pagination.
  """
  def get_offset(socket, key \\ :page, size \\ nil)
  def get_offset(socket, size, nil) when is_integer(size), do: get_offset(socket, :page, size)

  def get_offset(socket, key, size),
    do: (get_page(socket, key) - 1) * get_limit(socket, key, size)

  @doc """
  Returns `size`, or the page size of the `key` pagination. Raises if
  neither is set. With an integer second argument, it is the `size` of
  the `:page` pagination.
  """
  def get_limit(socket, key \\ :page, size \\ nil)
  def get_limit(socket, size, nil) when is_integer(size), do: get_limit(socket, :page, size)
  def get_limit(socket, key, nil), do: get_page_size(socket, key)
  def get_limit(_socket, _key, size) when is_integer(size) and size > 0, do: size

  @doc """
  Returns the number of pages of `count` items with the page size of the
  `key` pagination, at least `1` so an empty list still has its first
  page. Raises without a page size, like `get_page_size/2`.

      pages = Pagination.get_page_count(socket, Items.count())

      if Pagination.get_page(socket) > pages,
        do: push_patch(socket, to: Pagination.page_to(socket, pages))
  """
  def get_page_count(socket, key \\ :page, count) when is_integer(count) and count >= 0 do
    size = get_page_size(socket, key)
    max(div(count + size - 1, size), 1)
  end

  @doc """
  Returns the path of the current URI with `page` as the param of the
  `key` pagination, the other params kept. Page `1`, or less, removes
  the param.
  """
  def page_to(socket, key \\ :page, page) when is_integer(page) do
    page = if page > 1, do: page
    Params.build_to(%{config!(socket, key).page_param => page}, socket, mode: :merge)
  end

  @doc """
  Like `page_to/3`, with a page relative to the current one, e.g. `-1`
  for the previous page.
  """
  def page_rel_to(socket, key \\ :page, delta) when is_integer(delta),
    do: page_to(socket, key, get_page(socket, key) + delta)

  @doc """
  Returns the path of the current URI with `size` as the page size param
  of the `key` pagination, the other params kept but its page, so it goes
  back to the first page. The `:page_size` option removes the param.
  Raises if it was mounted without `:page_size_param`.
  """
  def page_size_to(socket, key \\ :page, size) when is_integer(size) and size > 0 do
    config = config!(socket, key)

    unless config.page_size_param do
      raise ArgumentError, "no :page_size_param for pagination #{inspect(key)}"
    end

    size = if size != config.page_size, do: size
    query = %{config.page_param => nil, config.page_size_param => size}
    Params.build_to(query, socket, mode: :merge)
  end

  @impl true
  def mount(arg, _params, _session, socket) do
    opts = opts(arg)
    key = opts[:key]

    Names.validate_opts!(opts, @defaults, "pagination")

    socket =
      socket
      |> Names.claim!(names(opts))
      |> put_private(
        private_key(key),
        Map.new(Keyword.take(opts, [:page_param, :page_size_param, :page_size]))
      )
      |> assign_new(key, fn -> %{page: 1, size: opts[:page_size]} end)

    {:cont, socket}
  end

  @impl true
  def unmount(arg, socket) do
    opts = opts(arg)
    socket = %{socket | private: Map.delete(socket.private, private_key(opts[:key]))}
    Names.release(socket, names(opts))
  end

  @impl true
  def handle_params(arg, params, uri, socket) do
    opts = opts(arg)

    pagination = %{
      page: parse_positive(params[opts[:page_param]], 1),
      size: parse_positive(params[opts[:page_size_param]], opts[:page_size])
    }

    socket =
      socket
      |> Params.put_uri(uri)
      |> assign(opts[:key], pagination)

    {:cont, socket}
  end

  @impl true
  def handle_event(arg, event, payload, socket) do
    opts = opts(arg)

    if event != nil and event == opts[:event] do
      key = opts[:key]
      value = &parse_int(get_in(payload, List.wrap(opts[&1])))

      to =
        case {value.(:event_size_path), value.(:event_page_path), value.(:event_rel_path)} do
          {size, _page, _rel} when is_integer(size) and size > 0 ->
            page_size_to(socket, key, size)

          {_size, page, _rel} when is_integer(page) ->
            page_to(socket, key, page)

          {_size, _page, rel} when is_integer(rel) ->
            page_rel_to(socket, key, rel)

          _invalid ->
            nil
        end

      {:halt, if(to, do: push_patch(socket, to: to), else: socket)}
    else
      {:cont, socket}
    end
  end

  defp private_key(key), do: {__MODULE__, key}

  defp names(opts) do
    [
      assign: opts[:key],
      event: opts[:event],
      param: opts[:page_param],
      param: opts[:page_size_param]
    ]
  end

  defp config!(socket, key) do
    case socket.private[private_key(key)] do
      nil -> raise ArgumentError, "pagination #{inspect(key)} is not mounted"
      config -> config
    end
  end

  defp pagination!(socket, key) do
    config!(socket, key)
    socket.assigns[key]
  end

  defp opts(:default), do: @defaults
  defp opts(opts) when is_list(opts), do: Keyword.merge(@defaults, opts)

  defp parse_positive(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> default
    end
  end

  defp parse_positive(_value, default), do: default

  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_int(_value), do: nil
end
