# Demo

A one-page LiveView with the `Search` and `Pagination` hooks: a list of
words to search, page through, add to and delete from.

```sh
mix deps.get
mix run --no-halt   # PORT=4001 mix run --no-halt for another port
```

Or with Docker, from the repo root:

```sh
docker build -f demo/Dockerfile -t live_reverse_hooks-demo .
docker run --rm -p 4000:4000 live_reverse_hooks-demo
```

CI pushes `main` to `ghcr.io/cescobaz/live_reverse_hooks-demo`.

Open http://localhost:4000. Each browser gets a user id in its session
cookie and its own copy of the preset words, kept in memory by the
`Demo.Words` GenServer.
