defmodule LastfmArchive.Lastfm.Factory do
  @moduledoc false

  # factory for generating Lastfm API responses test data
  defmacro __using__(_opts) do
    quote do
      def album_factory(attrs), do: %{"#text" => Map.get(attrs, :album), "mbid" => Map.get(attrs, :album_mbid)}

      def artist_factory(attrs) do
        %{
          "name" => Map.get(attrs, :artist),
          "mbid" => Map.get(attrs, :artist_mbid),
          "url" => Map.get(attrs, :artist_url),
          "image" => build(:artist_image, attrs)
        }
      end

      # placeholder for now
      def artist_image_factory(_attrs) do
        [
          %{
            "#text" => "https://lastfm.freetls.fastly.net/i/u/34s/2a96cbd8b46e442fc41c2b86b821562f.png",
            "size" => "small"
          },
          %{
            "#text" => "https://lastfm.freetls.fastly.net/i/u/64s/2a96cbd8b46e442fc41c2b86b821562f.png",
            "size" => "medium"
          },
          %{
            "#text" => "https://lastfm.freetls.fastly.net/i/u/174s/2a96cbd8b46e442fc41c2b86b821562f.png",
            "size" => "large"
          },
          %{
            "#text" => "https://lastfm.freetls.fastly.net/i/u/300x300/2a96cbd8b46e442fc41c2b86b821562f.png",
            "size" => "extralarge"
          }
        ]
      end

      def date_factory(attrs) do
        dt = Map.get(attrs, :datetime)

        %{
          "#text" => if(is_nil(dt), do: dt, else: dt |> Calendar.strftime("%d %b %Y, %X")),
          "uts" => Map.get(attrs, :datetime_unix) |> to_string()
        }
      end

      def track_attr_factory, do: %{"@attr" => %{"nowplaying" => "true"}}

      def track_image_factory(_attrs) do
        [
          %{
            "#text" => "https://lastfm.freetls.fastly.net/i/u/34s/18c9342a50264782a1f390bd18d50805.jpg",
            "size" => "small"
          },
          %{
            "#text" => "https://lastfm.freetls.fastly.net/i/u/64s/18c9342a50264782a1f390bd18d50805.jpg",
            "size" => "medium"
          },
          %{
            "#text" => "https://lastfm.freetls.fastly.net/i/u/174s/18c9342a50264782a1f390bd18d50805.jpg",
            "size" => "large"
          },
          %{
            "#text" => "https://lastfm.freetls.fastly.net/i/u/300x300/18c9342a50264782a1f390bd18d50805.jpg",
            "size" => "extralarge"
          }
        ]
      end

      def track_factory(attrs) do
        nowplaying = Map.get(attrs, :nowplaying, false)

        %{
          "album" => build(:album, attrs),
          "artist" => build(:artist, attrs),
          "date" => build(:date, attrs),
          "image" => build(:track_image, attrs),
          "loved" => "0",
          "mbid" => Map.get(attrs, :mbid),
          "name" => Map.get(attrs, :name),
          "streamable" => "0",
          "url" => Map.get(attrs, :url)
        }
        |> then(fn track ->
          case nowplaying do
            false -> track
            true -> Map.merge(track, build(:track_attr)) |> Map.delete("date")
          end
        end)
      end

      def recent_tracks_attr_factory(attrs) do
        %{
          "page" => Map.get(attrs, :page, "1"),
          "perPage" => Map.get(attrs, :per_page, "200"),
          "total" => Map.get(attrs, :total, "105"),
          "totalPages" => Map.get(attrs, :total_page, "1"),
          "user" => Map.get(attrs, :user, "a_lastfm_user")
        }
      end

      def recent_tracks_factory(attrs) do
        %{
          "recenttracks" => %{
            "@attr" => build(:recent_tracks_attr, attrs),
            "track" => for(s <- build(:scrobbles, attrs), do: build(:track, s |> Map.from_struct() |> Map.merge(attrs)))
          }
        }
      end

      def user_info_factory(attrs) do
        registered = Map.get(attrs, :registered_time, 1_472_601_600)

        %{
          "user" => %{
            "name" => Map.get(attrs, :user, "a_lastfm_user"),
            "playcount" => Map.get(attrs, :playcount, 388),
            "registered" => %{
              "#text" => registered |> DateTime.from_unix!() |> Calendar.strftime("%d %b %Y, %X"),
              "unixtime" => registered
            }
          }
        }
      end
    end
  end
end
