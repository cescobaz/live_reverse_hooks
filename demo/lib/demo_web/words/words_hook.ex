defmodule DemoWeb.Words.WordsHook do
  @moduledoc """
  Loads the words of a `Demo.Words` query into the `:words`, `:count` and
  `:pages` assigns, on every `handle_params` with a new query and on every
  event of the words of the query user. The first time it sees a user, it gives them
  their words with `Demo.Words.init_user/1`. Past the last page, e.g.
  after a delete, it patches to the last page.

  Mount it after the hooks that assign the query and the page:

      on_mount {LiveReverseHooks.Pagination, page_size: 10}
      on_mount MyLive.BuildQuery
      on_mount DemoWeb.Words.WordsHook

  ## Options

    * `:query_key` - the assign with the `Demo.Words` query. Defaults to
      `:query`.
    * `:page_key` - the key of the `LiveReverseHooks.Pagination` to use.
      Defaults to `:page`.
  """
  use LiveReverse
  import Phoenix.LiveView, only: [connected?: 1, push_patch: 2, put_private: 3]
  alias Demo.Words
  alias LiveReverseHooks.Pagination

  @defaults [query_key: :query, page_key: :page]

  @impl true
  def mount(arg, _params, _session, socket) do
    _opts = opts(arg)
    {:cont, assign(socket, words: [], count: 0, pages: 1)}
  end

  @impl true
  def handle_params(arg, _params, _uri, socket) do
    opts = opts(arg)
    {:cont, socket |> init_user(opts) |> maybe_load_words(opts)}
  end

  @impl true
  def handle_info(arg, {Words, _event, _word_or_user_id}, socket),
    do: {:halt, load_words(socket, opts(arg))}

  def handle_info(_arg, _msg, socket), do: {:cont, socket}

  # Once per query user: gives them their words and, once connected,
  # subscribes to their events.
  defp init_user(socket, opts) do
    user_id = socket.assigns[opts[:query_key]].user_id
    private_key = {__MODULE__, opts[:query_key]}

    case socket.private[private_key] do
      ^user_id ->
        socket

      previous ->
        {:ok, _created_or_exists} = Words.init_user(user_id)

        if connected?(socket) do
          if previous, do: Words.unsubscribe(previous)
          :ok = Words.subscribe(user_id)
        end

        put_private(socket, private_key, user_id)
    end
  end

  # Skips the load when the query is the one of the last load: the words
  # can't have changed without an event.
  defp maybe_load_words(socket, opts) do
    query = socket.assigns[opts[:query_key]]

    case socket.private[{__MODULE__, :loaded, opts[:query_key]}] do
      ^query -> socket
      _other -> load_words(socket, opts)
    end
  end

  defp load_words(socket, opts) do
    query = socket.assigns[opts[:query_key]]
    page_key = opts[:page_key]
    {:ok, count} = Words.count(query)
    pages = Pagination.get_page_count(socket, page_key, count)

    if Pagination.get_page(socket, page_key) > pages do
      push_patch(socket, to: Pagination.page_to(socket, page_key, pages))
    else
      {:ok, words} = Words.list(query)

      socket
      |> assign(words: words, count: count, pages: pages)
      |> put_private({__MODULE__, :loaded, opts[:query_key]}, query)
    end
  end

  defp opts(:default), do: @defaults
  defp opts(opts) when is_list(opts), do: Keyword.validate!(opts, @defaults)
end
