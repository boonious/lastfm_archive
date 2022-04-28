defmodule Lastfm.PathIO do
  @moduledoc false

  @callback wildcard(Path.t(), keyword) :: [binary]
end
