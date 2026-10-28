# Changelog

## v0.1.0 (unreleased)

First release.

- `LiveReverseHooks.Params`: binds URL params to assigns, with `build/2`,
  `build_to/2` and `put_uri/2`.
- `LiveReverseHooks.Search`: binds a search text to a URL param and a form
  event, with `search?/2`.
- `LiveReverseHooks.Pagination`: binds the current page to a URL param, with
  `get_page/2`, `get_page_size/2`, `get_offset/3`, `get_limit/3`,
  `page_to/3`, `page_rel_to/3` and `page_size_to/3`; several can be
  mounted, and the page size can come from a URL param.
