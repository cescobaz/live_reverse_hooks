# Demo

A one-page LiveView with the `Search` and `Pagination` hooks: a list of
words to search, page through, add to and delete from.

```sh
mix deps.get
mix run --no-halt   # PORT=4001 mix run --no-halt for another port
```

Open http://localhost:4000. Each browser gets a user id in its session
cookie and its own copy of the preset words, kept in memory by the
`Demo.Words` GenServer.
