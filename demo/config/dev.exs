import Config

# The library sits one level up (`../lib`), outside the demo project:
# recompile it as well and watch both lib dirs.
root = Path.expand("../..", __DIR__)

config :demo, DemoWeb.Endpoint,
  code_reloader: true,
  reloadable_apps: [:demo, :live_reverse_hooks],
  live_reload: [
    patterns: [~r"^#{Regex.escape(root)}/(demo/)?lib/.*\.ex$"]
  ]

config :phoenix_live_reload, :dirs, [Path.join(root, "lib"), Path.join(root, "demo/lib")]
