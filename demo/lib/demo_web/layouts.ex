defmodule DemoWeb.Layouts do
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
        <title>LiveReverseHooks demo</title>
        <style>
          :root { color-scheme: dark; }
          body { font-family: system-ui, sans-serif; margin: 0; background: #16181d; color: #e4e6eb; }
          .bar { display: flex; gap: 1rem; align-items: center; justify-content: flex-end; padding: .5rem 1rem; background: #1d2026; border-bottom: 1px solid #2d313a; }
          main { max-width: 32rem; margin: 2rem auto; padding: 0 1rem; }
          form { display: flex; gap: .5rem; margin-bottom: 1rem; }
          input, button { background: #22252c; color: inherit; border: 1px solid #3a3e48; border-radius: 4px; padding: .4rem .6rem; }
          input { flex: 1; }
          button { cursor: pointer; }
          button:hover:not(:disabled) { background: #2d313a; }
          button:disabled { opacity: .4; cursor: default; }
          ul { list-style: none; padding: 0; }
          li { display: flex; justify-content: space-between; align-items: center; padding: .3rem 0; border-bottom: 1px solid #2d313a; }
          nav { display: flex; gap: 1rem; align-items: center; justify-content: center; }
          .error { color: #f87171; }
          .muted { color: #8b8f99; font-size: .85rem; }
        </style>
        <script type="module">
          import {Socket} from "/assets/phoenix/phoenix.mjs"
          import {LiveSocket} from "/assets/phoenix_live_view/phoenix_live_view.esm.js"

          const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
          const liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
          liveSocket.connect()
        </script>
      </head>
      <body>
        {@inner_content}
      </body>
    </html>
    """
  end
end
