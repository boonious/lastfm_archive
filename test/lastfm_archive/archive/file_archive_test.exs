defmodule LastfmArchive.Archive.FileArchiveTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Hammox

  import LastfmArchive.Factory, only: [build: 2]
  import LastfmArchive.Utils, only: [user_dir: 1]
  import LastfmArchive.Utils.DateTime, only: [daily_time_ranges: 1]

  alias Explorer.DataFrame

  alias LastfmArchive.Archive.FileArchive
  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.Behaviour.Archive
  alias LastfmArchive.Behaviour.LastfmClient

  @column_count (%LastfmArchive.Archive.Scrobble{} |> Map.keys() |> length()) - 1
  @num_of_plays 3

  setup :verify_on_exit!

  setup_all do
    user = "a_lastfm_user"
    scrobbles = build(:recent_tracks, user: user, num_of_plays: @num_of_plays)

    %{
      user: user,
      metadata: build(:file_archive_metadata, creator: user),
      scrobbles: scrobbles,
      scrobbles_encoded: scrobbles |> Jason.encode!(),
      scrobbles_gzipped: scrobbles |> Jason.encode!() |> :zlib.gzip()
    }
  end

  describe "archive/3" do
    setup context do
      stub_with(LastfmClient.impl(), LastfmArchive.LastfmClientStub)
      stub_with(LastfmArchive.CacheMock, LastfmArchive.CacheStub)
      stub_with(LastfmArchive.FileIOMock, LastfmArchive.FileIOStub)

      stub(LastfmClient.impl(), :scrobbles, fn _, _, _ -> {:ok, context.scrobbles} end)
      Archive.impl() |> stub(:update_metadata, fn metadata, _options -> {:ok, metadata} end)

      :ok
    end

    test "calls Lastfm API via the client", %{metadata: metadata, scrobbles: scrobbles, user: user} do
      daily_playcount = 13
      {first_scrobble_time, last_scrobble_time} = metadata.temporal
      total_scrobbles = metadata.extent

      LastfmClient.impl()
      |> expect(:info, fn ^user, _client -> {:ok, {total_scrobbles, first_scrobble_time}} end)
      |> expect(:playcount, fn ^user, _time_range, _client -> {:ok, {total_scrobbles, last_scrobble_time}} end)
      |> stub(:playcount, fn ^user, _time_range, _api -> {:ok, {daily_playcount, last_scrobble_time}} end)
      |> stub(:scrobbles, fn ^user, _client_args, _client -> {:ok, scrobbles} end)

      Archive.impl()
      |> expect(:update_metadata, fn ^metadata, _options -> {:ok, metadata} end)
      |> expect(:update_metadata, fn metadata, _options -> {:ok, metadata} end)

      capture_log(fn -> assert {:ok, %Metadata{}} = FileArchive.archive(metadata, []) end)
    end

    test "scrobbles to files", %{metadata: metadata, scrobbles_encoded: scrobbles, user: user} do
      cache_dir = Path.join(user_dir(user), LastfmArchive.Cache.cache_dir())

      # ensure cache hiddern dir is available
      LastfmArchive.FileIOMock
      |> expect(:exists?, fn ^cache_dir -> false end)
      |> expect(:mkdir_p, fn ^cache_dir -> :ok end)

      # write 3 files for 3-day test archive duration
      LastfmArchive.FileIOMock
      |> expect(:exists?, 3, fn _page_dir -> false end)
      |> expect(:mkdir_p, 3, fn _page_dir -> :ok end)
      |> expect(:write, 3, fn path, ^scrobbles, [:compressed] ->
        assert path =~ "./lastfm_data/test/#{user}/2021/04"
        assert path =~ "/200_001.gz"
        :ok
      end)

      capture_log(fn -> FileArchive.archive(metadata, []) end)
    end

    test "scrobbles of a given year option", %{metadata: metadata, scrobbles_encoded: scrobbles} do
      opts = [year: 2021]

      LastfmArchive.FileIOMock
      |> expect(:write, 3, fn path, ^scrobbles, [:compressed] ->
        assert path =~ "/2021/"
        :ok
      end)

      capture_log(fn -> FileArchive.archive(metadata, opts) end)
    end

    test "scrobbles of a given date option", %{metadata: metadata, scrobbles_encoded: scrobbles} do
      opts = [date: ~D[2021-04-01]]

      LastfmArchive.FileIOMock
      |> expect(:write, fn path, ^scrobbles, [:compressed] ->
        assert path =~ "/2021/04/01"
        :ok
      end)

      capture_log(fn -> FileArchive.archive(metadata, opts) end)
    end

    test "overwrite scrobbles when opted", %{metadata: metadata, user: user} do
      daily_playcount = 13
      opts = [overwrite: true]

      cache_ok_status =
        metadata.temporal
        |> daily_time_ranges()
        |> Enum.into(%{}, fn time_range -> {time_range, {daily_playcount, [:ok]}} end)

      LastfmArchive.CacheMock |> expect(:get, fn {^user, 2021}, _cache -> cache_ok_status end)

      LastfmClient.impl() |> expect(:scrobbles, 3, fn _user, _client_args, _client -> {:ok, %{}} end)
      LastfmArchive.FileIOMock |> expect(:write, 3, fn _path, _data, [:compressed] -> :ok end)

      refute capture_log(fn -> assert {:ok, %Metadata{}} = FileArchive.archive(metadata, opts) end) =~ "Skipping"
    end

    test "raises when year option out of range", %{metadata: metadata} do
      assert_raise(RuntimeError, fn -> FileArchive.archive(metadata, year: 2023) end)
    end

    test "raises when date option out of range", %{metadata: metadata} do
      capture_log(fn -> assert_raise(RuntimeError, fn -> FileArchive.archive(metadata, date: ~D[2023-05-01]) end) end)
    end

    test "caches ok status", %{metadata: metadata, user: user} do
      LastfmArchive.CacheMock
      |> expect(:put, 3, fn {^user, 2021}, _time, {_playcount, [:ok]}, _opts, _cache -> :ok end)

      capture_log(fn -> FileArchive.archive(metadata, []) end)
    end

    test "caches status on Lastfm API call errors", %{metadata: metadata, user: user} do
      LastfmClient.impl() |> expect(:scrobbles, 3, fn _user, _client_args, _client -> {:error, "error"} end)

      LastfmArchive.CacheMock
      |> expect(:put, 3, fn {^user, 2021}, _time, {_playcount, [error: _data]}, _opts, _cache -> :ok end)

      assert capture_log(fn -> FileArchive.archive(metadata, []) end) =~ "Lastfm API error"
    end

    test "does not cache status of today's scrobbles (partial) archiving", %{metadata: metadata, user: user} do
      first_scrobble_time = (DateTime.utc_now() |> DateTime.to_unix()) - 100
      last_scrobble_time = DateTime.utc_now() |> DateTime.to_unix()
      total_scrobbles = 2

      metadata = %{
        metadata
        | temporal: {first_scrobble_time, last_scrobble_time},
          extent: total_scrobbles,
          date: Date.utc_today()
      }

      Archive.impl() |> stub(:update_metadata, fn _metadata, _options -> {:ok, metadata} end)

      LastfmClient.impl()
      |> expect(:info, fn ^user, _api -> {:ok, {total_scrobbles, first_scrobble_time}} end)
      |> expect(:playcount, 2, fn ^user, _time_range, _api -> {:ok, {total_scrobbles, last_scrobble_time}} end)
      |> expect(:scrobbles, fn ^user, _client_args, _client -> {:ok, %{}} end)

      LastfmArchive.CacheMock
      |> expect(:put, 0, fn {_user, _year}, {_from, _to}, {_total_scrobbles, _status}, _opts, _cache -> :ok end)

      assert capture_log(fn -> FileArchive.archive(metadata, []) end) =~ Date.utc_today() |> to_string
    end

    test "handles first total playcount API call error", %{metadata: metadata, user: user} do
      LastfmClient.impl() |> expect(:playcount, fn ^user, _time_range, _client -> {:error, "error"} end)
      assert FileArchive.archive(metadata, []) == {:error, "error"}
    end

    test "handles first user info API call error", %{metadata: metadata, user: user} do
      LastfmClient.impl() |> expect(:info, fn ^user, _client -> {:error, "error"} end)
      assert FileArchive.archive(metadata, []) == {:error, "error"}
    end

    test "handles and does not cache status of time-range playcount API call errors", %{
      metadata: metadata,
      scrobbles: scrobbles,
      user: user
    } do
      api_error = "error"
      {first_scrobble_time, last_scrobble_time} = metadata.temporal
      total_scrobbles = metadata.extent

      LastfmClient.impl()
      |> expect(:info, fn ^user, _client -> {:ok, {total_scrobbles, first_scrobble_time}} end)
      |> expect(:playcount, fn ^user, _time_range, _client -> {:ok, {total_scrobbles, last_scrobble_time}} end)
      |> stub(:playcount, fn ^user, _time_range, _api -> {:error, api_error} end)
      |> stub(:scrobbles, fn ^user, _client_args, _client -> {:ok, scrobbles} end)

      LastfmArchive.CacheMock
      |> expect(:put, 0, fn {^user, 2021}, _time, {_playcount, _status}, _opts, _cache -> :ok end)

      assert capture_log(fn -> FileArchive.archive(metadata, []) end) =~ "Lastfm API error"
    end

    test "does nothing when user have 0 scrobble", %{metadata: metadata} do
      LastfmClient.impl()
      |> expect(:info, 0, fn _user, _client -> {:ok, ""} end)
      |> expect(:playcount, 0, fn _user, _time_range, _client -> {:ok, ""} end)
      |> expect(:scrobbles, 0, fn _user, _client_args, _client -> {:ok, ""} end)

      LastfmArchive.FileIOMock |> expect(:write, 0, fn _path, _data, [:compressed] -> :ok end)

      assert {:ok, %Metadata{extent: 0}} = FileArchive.archive(%{metadata | extent: 0}, [])
    end

    test "does not write to files and make scrobbles calls on 0 playcount day", %{metadata: metadata} do
      daily_playcount = 0
      {first_scrobble_time, last_scrobble_time} = metadata.temporal
      total_scrobbles = metadata.extent

      LastfmClient.impl()
      |> expect(:info, fn _user, _client -> {:ok, {total_scrobbles, first_scrobble_time}} end)
      |> expect(:playcount, fn _user, _time_range, _client -> {:ok, {total_scrobbles, last_scrobble_time}} end)
      |> stub(:playcount, fn _user, _time_range, _api -> {:ok, {daily_playcount, last_scrobble_time}} end)
      |> expect(:scrobbles, 0, fn _user, _client_args, _client -> {:ok, ""} end)

      LastfmArchive.FileIOMock |> expect(:write, 0, fn _path, _data, [:compressed] -> :ok end)

      capture_log(fn -> assert {:ok, %Metadata{}} = FileArchive.archive(metadata, []) end)
    end

    test "skip archiving on ok status in cache", %{metadata: metadata, user: user} do
      daily_playcount = 13

      cache_ok_status =
        metadata.temporal
        |> daily_time_ranges()
        |> Enum.into(%{}, fn time_range -> {time_range, {daily_playcount, [:ok]}} end)

      LastfmArchive.CacheMock |> expect(:get, fn {^user, 2021}, _cache -> cache_ok_status end)

      LastfmClient.impl() |> expect(:scrobbles, 0, fn _user, _client_args, _client -> {:ok, ""} end)
      LastfmArchive.FileIOMock |> expect(:write, 0, fn _path, _data, [:compressed] -> :ok end)

      assert capture_log(fn -> assert {:ok, %Metadata{}} = FileArchive.archive(metadata, []) end) =~ "Skipping"
    end
  end

  describe "read/2" do
    test "returns data frame for a day's scrobbles", %{metadata: metadata, scrobbles_gzipped: scrobbles} do
      date = Date.utc_today()
      day = date |> to_string() |> String.replace("-", "/")
      archive_file = "200_001.gz"
      user_dir = user_dir(metadata.creator) <> "/#{day}"
      file_path = user_dir <> "/#{archive_file}"

      LastfmArchive.FileIOMock
      |> expect(:ls!, fn ^user_dir -> [archive_file] end)
      |> expect(:read, fn ^file_path -> {:ok, scrobbles} end)

      {:ok, %DataFrame{} = df} = FileArchive.read(metadata, day: date)
      assert {@num_of_plays, @column_count} == df |> DataFrame.collect() |> DataFrame.shape()
    end

    test "concats multi-page scrobbles of a day into a single data frame", %{
      metadata: metadata,
      scrobbles_gzipped: scrobbles
    } do
      date = Date.utc_today()

      LastfmArchive.FileIOMock
      |> expect(:ls!, fn _user_dir -> ["200_001.gz", "200_002.gz"] end)
      |> expect(:read, 2, fn _file_path -> {:ok, scrobbles} end)

      {:ok, %DataFrame{} = df} = FileArchive.read(metadata, day: date)
      assert {@num_of_plays * 2, @column_count} == df |> DataFrame.collect() |> DataFrame.shape()
    end

    test "returns data frame for a month's scrobbles", %{metadata: metadata, scrobbles_gzipped: scrobbles} do
      date = ~D[2023-06-01]
      user = "a_lastfm_user"
      user_dir = user_dir(user)
      wildcard_path = "#{user_dir}/2023/06/**/*.gz"

      files = [
        "#{user_dir}/2023/06/01/200_001.gz",
        "#{user_dir}/2023/06/02/200_001.gz",
        "#{user_dir}/2023/06/03/200_001.gz"
      ]

      LastfmArchive.PathIOMock |> expect(:wildcard, fn ^wildcard_path, _options -> files end)
      LastfmArchive.FileIOMock |> expect(:read, 3, fn _file_path -> {:ok, scrobbles} end)

      {:ok, %DataFrame{} = df} = FileArchive.read(metadata, month: date)
      assert {@num_of_plays * 3, @column_count} == df |> DataFrame.collect() |> DataFrame.shape()
    end

    test "when no day or month option given", %{metadata: metadata} do
      assert {:error, _reason} = FileArchive.read(metadata, [])
    end
  end
end
