defmodule LastfmArchive.MixProject do
  use Mix.Project

  @description """
    A tool for creating local Last.fm scrobble data archive and analytics
  """

  def project do
    [
      app: :lastfm_archive,
      version: "0.1.0",
      elixir: "~> 1.7",
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
      {:bypass, "~> 0.8.1", only: :test},
      {:elixirfm, "~> 0.1.3"},
      {:excoveralls, "~> 0.10", only: :test},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
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
