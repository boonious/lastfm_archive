defmodule LastfmArchive.Analytics.OnThisDay do
  @moduledoc false
  require Explorer.DataFrame
  alias Explorer.DataFrame

  def data_frame(format: format) do
    LastfmArchive.default_user()
    |> LastfmArchive.read(format: format)
    |> filter_data_frame()
  end

  defp filter_data_frame({:ok, df}) do
    df |> DataFrame.filter(contains(datetime, on_this_day()))
  end

  defp filter_data_frame(error), do: error

  defp on_this_day do
    %Date{month: month, day: day} = Date.utc_today()
    "-#{Integer.to_string(month) |> String.pad_leading(2, "0")}-#{Integer.to_string(day) |> String.pad_leading(2, "0")}"
  end
end
