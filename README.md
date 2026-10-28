# LiveReverseHooks

Ready-made [LiveReverse](https://github.com/cescobaz/live_reverse) hooks for
Phoenix LiveView. Plug them in with `on_mount`.

## Hooks

- **`LiveReverseHooks.Params`:** assigns URL params on every
  `handle_params`, and builds them back for a patch with `build/3` and
  `build_to/3`.

  ```elixir
  on_mount {LiveReverseHooks.Params, uri: :uri, project_id: "project_id"}
  ```

  `build/3` turns the bound assigns back into params, with overrides keyed
  by assign key (`nil` removes a param). `build_to/3` sets them as the
  query of the current URI and returns the path, so the URI only carries
  the bound params:

  ```elixir
  on_mount {LiveReverseHooks.Params, project_id: "project_id", page: "page"}

  def handle_event("next_page", _params, socket) do
    page = String.to_integer(socket.assigns.page || "1") + 1

    # => "/projects/g1?page=2&project_id=g1"
    to = socket |> Params.build(page: page) |> Params.build_to(socket)

    {:noreply, push_patch(socket, to: to)}
  end

  def handle_event("first_page", _params, socket) do
    # => "/projects/g1?project_id=g1"
    to = socket |> Params.build(page: nil) |> Params.build_to(socket)

    {:noreply, push_patch(socket, to: to)}
  end
  ```

  With `mode: :merge`, `build_to/3` keeps the other params of the URI
  instead, and `keep_nil: true` lets `build/3` remove params from it:

  ```elixir
  # => "/projects/g1?other=1&project_id=g1", from "/projects/g1?other=1&page=2"
  socket |> Params.build([page: nil], keep_nil: true) |> Params.build_to(socket, mode: :merge)
  ```

- **`LiveReverseHooks.Search`:** binds a search text to a URL param and a
  form event; the event assigns the text and patches the URL.

  ```elixir
  on_mount LiveReverseHooks.Search
  on_mount {LiveReverseHooks.Search, key: :tag_search, param: "q", event: "tag_search"}
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
