# Changelog

## v0.1.0 (unreleased)

First release.

- `LiveReverseHooks.Params`: binds URL params to assigns, with `build/3`,
  `build_to/3` and `put_uri/2`; `build/3` keeps the params of the other
  hooks.
- Assign keys, query params and events can't be used twice, across the
  hooks.
- `LiveReverseHooks.Search`: binds a search text to a URL param and a form
  event, with `get_search/2`, `search?/2` and `build_params/2`; a new
  search drops the `:drop_params_on_change` params, and a module that
  uses it can override the `handle_search_change/3` callback.
- `LiveReverseHooks.Pagination`: binds the current page to a URL param, with
  `get_page/2`, `get_page_size/2`, `get_offset/3`, `get_limit/3`,
  `get_page_count/3`, `page_to/3`, `page_rel_to/3` and `page_size_to/3`;
  several can be mounted, the page size can come from a URL param, and an
  event patches to a page, a relative page or a size.
