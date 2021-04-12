defmodule Lastfm.PathIO do
  @callback wildcard(Path.t(), keyword) :: [binary]
end
