defmodule LastfmArchive.Archive.Transformers.TransformerConfigs do
  @moduledoc false
  alias LastfmArchive.Archive.Transformers

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      defdelegate facets, to: unquote(__MODULE__)
      defdelegate formats, to: unquote(__MODULE__)

      def facet_transformer_config(facet), do: facet_transformers_configs()[facet]

      def format_config(mimetype) do
        format_configs() |> Enum.find(fn {_format, %{mimetype: type}} -> type == mimetype end)
      end

      def validate_opts(opts) do
        opts
        |> Enum.filter(fn {k, _} -> k in (default_opts() |> Keyword.keys()) end)
        |> Keyword.validate!(default_opts())
      end

      def mimetype(format), do: format_configs()[format][:mimetype]
      def read_opts(format), do: format_configs()[format][:read_opts]
      def write_opts(format), do: format_configs()[format][:write_opts]
    end
  end

  def default_opts, do: [facet: :scrobbles, format: :ipc_stream, overwrite: false, year: nil]
  def facets, do: facet_transformers_configs() |> Map.keys()
  def formats, do: format_configs() |> Map.keys()

  def format_configs do
    %{
      csv: %{mimetype: "text/tab-separated-values", read_opts: [delimiter: "\t"], write_opts: [delimiter: "\t"]},
      parquet: %{mimetype: "application/vnd.apache.parquet", read_opts: [], write_opts: [compression: {:gzip, 9}]},
      ipc: %{mimetype: "application/vnd.apache.arrow.file", read_opts: [], write_opts: [compression: :zstd]},
      ipc_stream: %{mimetype: "application/vnd.apache.arrow.stream", read_opts: [], write_opts: [compression: :zstd]}
    }
  end

  def facet_transformers_configs do
    %{
      scrobbles: %{transformer: Transformers.LocalFileArchiveTransformer},
      artists: %{transformer: Transformers.FacetsTransformer, group: [:artist, :year, :mmdd]},
      albums: %{transformer: Transformers.FacetsTransformer, group: [:album, :album_mbid, :artist, :year, :mmdd]},
      tracks: %{transformer: Transformers.FacetsTransformer, group: [:track, :album, :artist, :mbid, :year, :mmdd]}
    }
  end
end
