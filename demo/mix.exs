defmodule Demo.MixProject do
  use Mix.Project

  def project do
    [
      app: :demo,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  def application do
    [
      mod: {Demo.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:live_reverse_hooks, path: ".."},
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.0"},
      {:bandit, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:phoenix_live_reload, "~> 1.6", only: :dev}
    ]
  end
end
