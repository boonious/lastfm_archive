defmodule LastfmArchive.Analytics.OnThisDay do
  @moduledoc """
  Create on this day analytics and display them in Livebook.
  """

  use LastfmArchive.Behaviour.Analytics, facets: LastfmArchive.Analytics.Settings.available_facets()
  use LastfmArchive.Behaviour.LivebookAnalytics, facets: LastfmArchive.Analytics.Settings.available_facets()

  require Explorer.DataFrame
  alias Explorer.DataFrame

  def columns, do: ["id", "artist", "datetime", "year", "album", "name"]

  def data_frame(format: format) do
    [format: format]
    |> read_data_frame()
    |> filter_data_frame()
  end

  defp read_data_frame(format: format) do
    LastfmArchive.default_user() |> LastfmArchive.read(format: format, columns: columns())
  end

  defp filter_data_frame({:ok, df}), do: df |> DataFrame.filter(contains(datetime, this_day()))
  defp filter_data_frame(error), do: error

  def this_day(format \\ "-%m-%d"), do: Date.utc_today() |> Calendar.strftime(format)

  def render_overview(%Explorer.DataFrame{} = df) do
    df
    |> overview_ui()
    |> Kino.render()
  end

  def render_most_played(df) do
    [
      top_artists(df, rows: 8) |> most_played_ui(),
      top_albums(df, rows: 8) |> most_played_ui(),
      top_tracks(df, rows: 8) |> most_played_ui()
    ]
    |> Kino.Layout.grid(columns: 3)
  end
end
