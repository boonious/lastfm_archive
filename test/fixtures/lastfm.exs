defmodule Fixtures.Lastfm do
  def user_info(user, count, registered) do
    ~s"""
       {
         "user": {
           "name": "#{user}",
           "playcount": #{count},
           "registered": {"#text": #{registered}, "unixtime": #{registered}}
        }
      }
    """
  end

  def recent_tracks(user, count) do
    ~s"""
     {
       "recenttracks": {
         "track": [],
         "@attr": {
           "user": "#{user}",
           "page": 1,
           "perPage": 1,
           "totalPages": 12,
           "total": #{count}
         }
      }
    }
    """
  end
end
