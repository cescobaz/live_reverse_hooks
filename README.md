# LiveReverseHooks

Ready-made [LiveReverse](https://github.com/cescobaz/live_reverse) hooks for
Phoenix LiveView. Plug them in with `on_mount`.

## Hooks

- **`LiveReverseHooks.Params`:** assigns URL params on every
  `handle_params`, and builds them back for a patch with `build/3` and
  `build_to/3`.

  ```elixir
  on_mount {LiveReverseHooks.Params, uri: :uri, project_id: {:path, "id"}, page: "page"}
  ```

  A binding is `{:path, name}` for a path param, `{:query, name}` or just
  `name` for a query param, or `:uri` for the full URI.

  `build/3` turns the bound assigns back into query params (path and `:uri`
  bindings are skipped), with overrides keyed
  by assign key (`nil` removes a param). `build_to/3` sets them as the
  query of the current URI and returns the path, so the URI only carries
  the bound params:

  ```elixir
  # live "/projects/:id", ProjectLive
  on_mount {LiveReverseHooks.Params, project_id: {:path, "id"}, page: "page"}

  def handle_event("next_page", _params, socket) do
    page = String.to_integer(socket.assigns.page || "1") + 1

    # => "/projects/g1?page=2"
    to = socket |> Params.build(page: page) |> Params.build_to(socket)

    {:noreply, push_patch(socket, to: to)}
  end

  def handle_event("first_page", _params, socket) do
    # => "/projects/g1"
    to = socket |> Params.build(page: nil) |> Params.build_to(socket)

    {:noreply, push_patch(socket, to: to)}
  end
  ```

  With `mode: :merge`, `build_to/3` keeps the other params of the URI
  instead, and `keep_nil: true` lets `build/3` remove params from it:

  ```elixir
  # => "/projects/g1?other=1", from "/projects/g1?other=1&page=2"
  socket |> Params.build([page: nil], keep_nil: true) |> Params.build_to(socket, mode: :merge)
  ```

- **`LiveReverseHooks.Search`:** binds a search text to a URL param and a
  form event; the event assigns the text and patches the URL.

  ```elixir
  on_mount LiveReverseHooks.Search
  on_mount {LiveReverseHooks.Search, key: :tag_search, param: "q", event: "tag_search"}
  ```

- **`LiveReverseHooks.Pagination`:** binds the current page to a URL
  param, with a page size (`20` by default). Both go to the `:key` assign
  as `%{page: 3, size: 20}`, so a change renders. `get_offset/3` and
  `get_limit/3` give the query window, `page_to/3` and `page_rel_to/3`
  the path to patch to. List it once per panel, each with its own `:key`
  and `:param`, to have several paginations; the functions take the
  `:key`, `:page` by default. With `param_size: "users_page_size"` the
  page size comes from that param too (`:size` is the fallback), and
  `page_size_to/3` builds the path to change it.

  ```elixir
  on_mount {LiveReverseHooks.Pagination, key: :page, param: "page", size: 20}

  items = Items.list(offset: Pagination.get_offset(socket), limit: Pagination.get_limit(socket))

  # previous page
  push_patch(socket, to: Pagination.page_rel_to(socket, -1))
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
