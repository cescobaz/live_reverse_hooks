# LiveReverseHooks

Ready-made [LiveReverse](https://github.com/cescobaz/live_reverse) hooks for
Phoenix LiveView. Plug them in with `on_mount`.

## Hooks

- **`LiveReverseHooks.Params`:** assigns URL params on every
  `handle_params`, and builds them back for a patch with `build/2` and
  `build_to/2`.

  ```elixir
  on_mount {LiveReverseHooks.Params, uri: :uri, project_id: "project_id"}
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
