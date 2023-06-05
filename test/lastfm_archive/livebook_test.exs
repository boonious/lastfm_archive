defmodule LastfmArchive.LivebookTest do
  use ExUnit.Case, async: true
  alias LastfmArchive.Livebook, as: LFM_LB

  test "info/0" do
    assert %Kino.Markdown{} = LFM_LB.info()
  end
end
