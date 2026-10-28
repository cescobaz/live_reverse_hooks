# LiveReverseHooks

Ready-made [LiveReverse](https://github.com/cescobaz/live_reverse) hooks for
Phoenix LiveView. Plug them in with `on_mount`.

## Hooks

Each hook runs before the LiveView's own callbacks, so in `handle_params/3`
the assigns are already set from the URL. All hooks of this library share
the URL: a patch from one keeps the params of the others, and binding the
same assign, param or event twice raises.

### Params

`LiveReverseHooks.Params` assigns URL params on every `handle_params`.

- Set the params to listen to: path (`{:path, "id"}`), query (`"tab"`)
  or the full URI (`:uri`).
- Read them as assigns, anywhere: callbacks, `render/1`, components.
  Empty strings come as `nil`.
- Build a `:to` for navigation easily with `build/3` + `build_to/3`,
  without missing a query key.

```elixir
defmodule MyAppWeb.ProjectLive do
  use MyAppWeb, :live_view
  alias LiveReverseHooks.Params

  # live "/projects/:id", ProjectLive
  on_mount {Params, project_id: {:path, "id"}, tab: "tab"}

  def handle_params(_params, _uri, socket) do
    # @project_id and @tab are already assigned here.
    #
    # Yes, this is a Repo call straight from the LiveView. Somewhere a
    # senior engineer just spilled their coffee and doesn't know why.
    # Put it in a context. Do it for them.
    project = MyApp.Repo.get!(MyApp.Project, socket.assigns.project_id)

    {:noreply, assign(socket, :project, project)}
  end

  def handle_event("show_tab", %{"tab" => tab}, socket) do
    # => "/projects/42?tab=members"
    to = socket |> Params.build(tab: tab) |> Params.build_to(socket)

    {:noreply, push_patch(socket, to: to)}
  end

  def render(assigns) do
    ~H"""
    <h1>{@project.name}</h1>
    <button phx-click="show_tab" phx-value-tab="overview">Overview</button>
    <button phx-click="show_tab" phx-value-tab="members">Members</button>
    <.members :if={@tab == "members"} project={@project} />
    """
  end
end
```

### Search

`LiveReverseHooks.Search` binds a search text to a URL param and a form
event.

- Set the param to listen to (default `"search"`), it lands in the
  `:search` assign.
- Set the event to listen to (default `"search"`), it changes the param
  for you.
- Attach a `<form phx-change="search">` to the view, the job is done.
- Read it with `get_search/2` or `search?/2`.

```elixir
defmodule MyAppWeb.UserLive do
  use MyAppWeb, :live_view
  alias LiveReverseHooks.Search

  on_mount Search

  def handle_params(_params, _uri, socket) do
    users =
      if Search.search?(socket),
        do: MyApp.Accounts.search_users(Search.get_search(socket)),
        else: MyApp.Accounts.list_users()

    {:noreply, assign(socket, :users, users)}
  end

  def render(assigns) do
    ~H"""
    <form phx-change="search" phx-submit="search">
      <input type="search" name="search" value={@search} phx-debounce="300" />
    </form>
    <ul>
      <li :for={user <- @users}>{user.name}</li>
    </ul>
    """
  end
end
```

### Pagination

`LiveReverseHooks.Pagination` binds the current page to a URL param.

- Set the param to listen to (default `"page"`), it lands in the
  `:page` assign as `%{page: 3, size: 20}`.
- Set the event to listen to (default `"page"`), it changes the param
  for you.
- Attach a `<button phx-click="page" phx-value-rel="1">` to the view,
  the job is done.
- Query with `get_offset/3` and `get_limit/3`.

```elixir
defmodule MyAppWeb.ItemLive do
  use MyAppWeb, :live_view
  alias LiveReverseHooks.Pagination

  on_mount {Pagination, page_size: 20, page_size_param: "size"}

  def handle_params(_params, _uri, socket) do
    items =
      MyApp.Items.list(
        offset: Pagination.get_offset(socket),
        limit: Pagination.get_limit(socket)
      )

    {:noreply, assign(socket, :items, items)}
  end

  def render(assigns) do
    ~H"""
    <ul>
      <li :for={item <- @items}>{item.name}</li>
    </ul>
    <button phx-click="page" phx-value-rel="-1" disabled={@page.page == 1}>Previous</button>
    <span>Page {@page.page}</span>
    <button phx-click="page" phx-value-rel="1">Next</button>
    <button phx-click="page" phx-value-size="50">50 per page</button>
    """
  end
end
```

See the module docs for the details.

## Installation

Add `live_reverse_hooks` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_reverse_hooks, git: "git@github.com:cescobaz/live_reverse_hooks.git", branch: "main"}
  ]
end
```

## License

MIT, see the `LICENSE` file.
