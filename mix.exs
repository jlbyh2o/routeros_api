defmodule RouterosApi.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/jlbyh2o/routeros_api"

  def project do
    [
      app: :routeros_api,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      name: "RouterOS API",
      source_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto, :ssl],
      mod: {RouterosApi.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_pool, "~> 1.0"},
      {:telemetry, "~> 1.0"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    Elixir client for MikroTik RouterOS binary API with connection pooling, telemetry,
    and helper functions. Supports RouterOS 6.x and 7.x with both MD5 and plain text
    authentication over TCP and TLS.
    """
  end

  defp package do
    [
      name: "routeros_api",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      main: "RouterosApi",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:ex_unit, :mix],
      flags: [
        :unmatched_returns,
        :error_handling,
        :underspecs
      ]
    ]
  end
end
