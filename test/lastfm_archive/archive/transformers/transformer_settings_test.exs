defmodule LastfmArchive.Archive.Transformers.TransformerSettingsTest do
  use ExUnit.Case, async: true
  alias LastfmArchive.Archive.Transformers.TransformerSettings

  describe "validate_opts/1" do
    test "returns defaults options" do
      opts = []

      for opt <- TransformerSettings.validate_opts(opts) do
        assert opt in TransformerSettings.default_opts()
      end
    end

    test "use option(s) if given" do
      opts = [format: :csv]

      assert TransformerSettings.validate_opts(opts) |> length() == TransformerSettings.default_opts() |> length()

      for opt <- TransformerSettings.validate_opts(opts) do
        assert opt in (TransformerSettings.default_opts() |> Keyword.replace!(:format, :csv))
      end
    end

    test "remove unrelated options" do
      opts = [format: :csv, non_transformer_opt: 1234]

      assert TransformerSettings.validate_opts(opts) |> length() == TransformerSettings.default_opts() |> length()
      assert {:format, :csv} in TransformerSettings.validate_opts(opts)
      refute {:non_transformer_opt, 1234} in TransformerSettings.validate_opts(opts)
    end
  end
end
