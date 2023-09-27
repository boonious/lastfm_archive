defmodule LastfmArchive.Utils.Archive do
  @moduledoc false

  require Logger

  @metadata_dir ".metadata"
  @data_dir Application.compile_env(:lastfm_archive, :data_dir, "./lastfm_data/")

  def metadata_filepath(user, opts \\ []) do
    Path.join([
      Keyword.get(opts, :data_dir) || data_dir(),
      user,
      "#{@metadata_dir}/#{Keyword.get(opts, :facet, "scrobbles")}/#{Keyword.get(opts, :format, "json")}_archive"
    ])
  end

  def num_pages(playcount, per_page), do: (playcount / per_page) |> :math.ceil() |> round

  # returns 2021/12/31/200_001 type paths
  def page_path(datetime, page, per_page) do
    page_num = page |> to_string() |> String.pad_leading(3, "0")

    datetime
    |> DateTime.from_unix!()
    |> DateTime.to_date()
    |> Date.to_string()
    |> String.replace("-", "/")
    |> Path.join("#{per_page}_#{page_num}")
  end

  def derived_archive_dir(opts), do: "derived/#{Keyword.fetch!(opts, :facet)}/#{Keyword.fetch!(opts, :format)}"

  def user_dir(user), do: Path.join([data_dir(), user])
  def user_dir(user, opts), do: Path.join([data_dir(opts), user])

  defp data_dir(), do: @data_dir
  defp data_dir(opts), do: Keyword.get(opts, :data_dir, data_dir())
end
