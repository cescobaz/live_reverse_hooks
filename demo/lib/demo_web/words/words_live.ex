defmodule DemoWeb.Words.WordsLive do
  use Phoenix.LiveView
  alias DemoWeb.Components.{PaginationNav, SearchForm}
  alias DemoWeb.Users.UserHeader
  alias DemoWeb.Words.{WordForm, WordList}
  alias LiveReverseHooks.{Pagination, Search}
  require LiveReverse

  # First: the other hooks read the :user_id assign.
  on_mount DemoWeb.Users.UserHook

  on_mount {Search, drop_params_on_change: ["page"]}
  on_mount {Pagination, page_size: 10}

  # Runs after Search and Pagination: builds the Demo.Words query of the
  # current search and page.
  #
  # It is inline only to show LiveReverse.inline: it is a plain
  # LiveReverse module, defined here and mounted in place. It could as
  # well be a dedicated module in its own file, like the hooks in
  # DemoWeb.Words, mounted with `on_mount`.
  LiveReverse.inline BuildQuery do
    @impl true
    def handle_params(_arg, _params, _uri, socket) do
      query = %{
        user_id: socket.assigns.user_id,
        search: Search.get_search(socket),
        offset: Pagination.get_offset(socket),
        limit: Pagination.get_limit(socket)
      }

      {:cont, assign(socket, :query, query)}
    end
  end

  # Loads the words of the query, and again on every change of them.
  on_mount DemoWeb.Words.WordsHook

  # The form that adds a word.
  on_mount DemoWeb.Words.WordFormHook

  # The delete buttons and the reset button.
  on_mount DemoWeb.Words.WordDeleteHook
  on_mount DemoWeb.Words.WordResetHook

  # The hooks do the work, but LiveView calls it on every patch.
  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <UserHeader.render user_id={@user_id}>
      <button phx-click="reset">Reset words</button>
    </UserHeader.render>

    <main>
      <h1>Words</h1>
      <SearchForm.render search={@search} />
      <WordForm.render form={@form} />
      <WordList.render words={@words} />
      <PaginationNav.render page={@page.page} pages={@pages}>
        ({@count} words)
      </PaginationNav.render>
    </main>
    """
  end
end
