defmodule LastfmArchive.MixProject do
  use Mix.Project

  @description """
    A tool for creating local Last.fm scrobble file archive, Solr archive and analytics
  """

  def project do
    [
      app: :lastfm_archive,
      version: "0.7.2",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: LastfmArchive.Cli, path: "bin/lastfm_archive"],
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

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:bypass, "~> 2.1", only: :test},
      {:excoveralls, "~> 0.13", only: :test},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:httpoison, "~> 1.5"},
      {:poison, "~> 4.0.1"},
      {:hui, "~> 0.10"}
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
