import Config

{:ok, ip} = System.get_env("IP", "127.0.0.1") |> String.to_charlist() |> :inet.parse_address()

config :demo, DemoWeb.Endpoint,
  http: [ip: ip, port: String.to_integer(System.get_env("PORT", "4000"))]
