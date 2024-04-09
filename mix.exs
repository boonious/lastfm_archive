defmodule LastfmArchive.MixProject do
  use Mix.Project

  @description """
    A tool for extracting and archiving Last.fm music listening data - scrobbles.
  """

  def project do
    [
      app: :lastfm_archive,
      version: "1.2.1",
      elixir: "~> 1.14",
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
        main: "readme",
        extras: [
          "README.md",
          "CHANGELOG.md",
          "livebook/setup.livemd": [title: "Setup, installation"],
          "livebook/archiving.livemd": [title: "Creating a file archive"],
          "livebook/transforming.livemd": [title: "Columnar data transforms"],
          "livebook/facets.livemd": [title: "Facets archiving"]
        ],
        groups_for_extras: [
          Guides: Path.wildcard("livebook/*.livemd")
        ],
        assets: "assets",
        source_ref: "master"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "test/fixtures", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: {LastfmArchive.Application, []}
    ]
  end

  defp deps do
    [
      {:castore, "~> 1.0"},
      {:elixir_uuid, "~> 1.2"},
      {:explorer, "~> 0.7"},
      {:hui, "0.10.4"},
      {:jason, "~> 1.4"},
      {:kino, "~> 0.10.0"},
      {:kino_vega_lite, "~> 0.1.9"},
      {:stow, path: "../stow"},
      {:typed_struct, "~> 0.3.0"},
      {:vega_lite, "~> 0.1.7"},

      # test and dev only
      {:bypass, "~> 2.1", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.16", only: :test},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:ex_machina, "~> 2.7", only: :test},
      {:hammox, "~> 0.7", only: :test}
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
