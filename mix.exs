defmodule LastfmArchive.MixProject do
  use Mix.Project

  @description """
    A tool for creating local Last.fm scrobble file archive, Solr archive and analytics
  """

  def project do
    [
      app: :lastfm_archive,
      version: "0.8.0",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],

      # Docs
      name: "lastfm_archive",
      description: @description,
      package: package(),
      source_url: "https://github.com/boonious/lastfm_archive",
      homepage_url: "https://github.com/boonious/lastfm_archive",
      docs: [
        main: "LastfmArchive",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: {LastfmArchive.Application, []}
    ]
  end

  defp deps do
    [
      {:bypass, "~> 2.1", only: :test},
      {:excoveralls, "~> 0.13", only: :test},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:hammox, "~> 0.4", only: :test},
      {:hui, "~> 0.10"},
      {:jason, "~> 1.2"}
    ]
  end

  defp package do
    [
      name: "lastfm_archive",
      maintainers: ["Boon Low"],
      licenses: ["Apache 2.0"],
      links: %{
        Changelog: "https://github.com/boonious/lastfm_archive/blob/master/CHANGELOG.md",
        GitHub: "https://github.com/boonious/lastfm_archive"
      }
    ]
  end
end
