defmodule LiveReverseHooks.Pagination do
  @moduledoc ~S"""
  Binds the current page to a URL param.

  On `handle_params` the page and its size are assigned to `:key` as
  `%{page: page, size: size}`, so a change of either renders. A missing,
  invalid or less than 1 page is `1`; the size comes from the
  `:param_size` param, or `:size` without one.

      on_mount LiveReverseHooks.Pagination
      on_mount {LiveReverseHooks.Pagination, key: :page, param: "p", size: 20}

  `get_offset/3` and `get_limit/3` turn the page into a query window, and
  `page_to/3` and `page_rel_to/3` build the path to patch to:

      items = Items.list(offset: Pagination.get_offset(socket), limit: Pagination.get_limit(socket))

      push_patch(socket, to: Pagination.page_rel_to(socket, 1))

  ## Several paginations

  It can be listed more than once, e.g. one per panel, each with its own
  `:key` and `:param`. The functions take the `:key` of the pagination
  to use, `:page` by default:

      on_mount {LiveReverseHooks.Pagination, key: :users_page, param: "users_page"}
      on_mount {LiveReverseHooks.Pagination, key: :groups_page, param: "groups_page", size: 10}

      Pagination.get_offset(socket, :groups_page)
      Pagination.page_rel_to(socket, :users_page, 1)

  ## Options

    * `:key` - the assign with the page and size, also naming the
      pagination.
      Defaults to `:page`.
    * `:param` - the URL param. Defaults to `"page"`.
    * `:size` - the page size, `nil` for none. Defaults to `20`.
    * `:param_size` - the URL param with the page size, e.g.
      `"users_page_size"`. A missing or invalid one falls back to `:size`.
      Defaults to `nil`, a fixed page size.
  """
  use LiveReverse
  import Phoenix.LiveView, only: [put_private: 3]
  alias LiveReverseHooks.Params

  @defaults [key: :page, param: "page", size: 20, param_size: nil]

  @doc """
  Returns the current page of the `key` pagination, starting at `1`.
  """
  def get_page(socket, key \\ :page), do: pagination!(socket, key).page

  @doc """
  Returns the page size of the `key` pagination. Raises if it was mounted
  with `size: nil` and the `:param_size` param is not set.
  """
  def get_page_size(socket, key \\ :page) do
    case pagination!(socket, key).size do
      nil ->
        raise ArgumentError, "no page size for pagination #{inspect(key)}, mounted with size: nil"

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
  Returns the path of the current URI with `page` as the param of the
  `key` pagination, the other params kept. Page `1`, or less, removes
  the param.
  """
  def page_to(socket, key \\ :page, page) when is_integer(page) do
    page = if page > 1, do: page
    Params.build_to(%{config!(socket, key).param => page}, socket, mode: :merge)
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
  back to the first page. The `:size` option removes the param. Raises if
  it was mounted without `:param_size`.
  """
  def page_size_to(socket, key \\ :page, size) when is_integer(size) and size > 0 do
    config = config!(socket, key)

    unless config.param_size do
      raise ArgumentError, "no :param_size for pagination #{inspect(key)}"
    end

    size = if size != config.size, do: size
    query = %{config.param => nil, config.param_size => size}
    Params.build_to(query, socket, mode: :merge)
  end

  @impl true
  def mount(arg, _params, _session, socket) do
    opts = opts(arg)
    key = opts[:key]

    if socket.private[private_key(key)] do
      raise ArgumentError, "pagination #{inspect(key)} is already mounted"
    end

    socket =
      socket
      |> put_private(private_key(key), Map.new(Keyword.take(opts, [:param, :param_size, :size])))
      |> assign_new(key, fn -> %{page: 1, size: opts[:size]} end)

    {:cont, socket}
  end

  @impl true
  def unmount(arg, socket) do
    %{socket | private: Map.delete(socket.private, private_key(opts(arg)[:key]))}
  end

  @impl true
  def handle_params(arg, params, uri, socket) do
    opts = opts(arg)

    pagination = %{
      page: parse_positive(params[opts[:param]], 1),
      size: parse_positive(params[opts[:param_size]], opts[:size])
    }

    socket =
      socket
      |> Params.put_uri(uri)
      |> assign(opts[:key], pagination)

    {:cont, socket}
  end

  defp private_key(key), do: {__MODULE__, key}

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
end
