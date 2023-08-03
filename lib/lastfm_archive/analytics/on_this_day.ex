defmodule LastfmArchive.Analytics.OnThisDay do
  @moduledoc false

  require Explorer.DataFrame
  alias Explorer.DataFrame

  def columns, do: ["id", "artist", "datetime", "year", "album", "name"]

  def data_frame(format: format) do
    LastfmArchive.default_user()
    |> LastfmArchive.read(format: format, columns: columns())
    |> filter_data_frame()
  end

  defp filter_data_frame({:ok, df}) do
    df |> DataFrame.filter(contains(datetime, this_day()))
  end

  defp filter_data_frame(error), do: error

  def this_day(format \\ "-%m-%d"), do: Date.utc_today() |> Calendar.strftime(format)
end
