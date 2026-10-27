defmodule LiveReverseHooks.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/cescobaz/live_reverse_hooks"

  def project do
    [
      app: :live_reverse_hooks,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "LiveReverseHooks",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:live_reverse, git: "git@github.com:cescobaz/live_reverse.git", branch: "main"},
      {:phoenix_live_view, "~> 1.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Ready-made LiveReverse hooks for Phoenix LiveView: URL params and search."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
