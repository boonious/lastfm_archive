defmodule LastfmArchive.Archive.Transformers.TransformerSettings do
  @moduledoc false
  alias LastfmArchive.Archive.Transformers

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      def derived_archive_dir(opts \\ default_opts()) do
        opts
        |> validate_opts()
        |> then(fn opts -> "derived/#{opts[:facet]}/#{opts[:format]}" end)
      end

      defdelegate facets, to: unquote(__MODULE__)
      defdelegate formats, to: unquote(__MODULE__)
      def mimetype(format), do: format_settings()[format][:mimetype]
      def read_opts(format), do: format_settings()[format][:read_opts]
      def write_opts(format), do: format_settings()[format][:write_opts]
      def setting(mimetype), do: format_settings() |> Enum.find(fn {_format, %{mimetype: type}} -> type == mimetype end)
    end
  end

  def default_opts, do: [format: :ipc_stream, facet: :scrobbles, overwrite: false]

  def validate_opts(opts) do
    opts
    |> Enum.filter(fn {k, _} -> k in (default_opts() |> Keyword.keys()) end)
    |> Keyword.validate!(default_opts())
  end

  def facets, do: facet_transformers_settings() |> Map.keys()
  def formats, do: format_settings() |> Map.keys()

  def format_settings do
    %{
      csv: %{mimetype: "text/tab-separated-values", read_opts: [delimiter: "\t"], write_opts: [delimiter: "\t"]},
      parquet: %{mimetype: "application/vnd.apache.parquet", read_opts: [], write_opts: [compression: {:gzip, 9}]},
      ipc: %{mimetype: "application/vnd.apache.arrow.file", read_opts: [], write_opts: [compression: :zstd]},
      ipc_stream: %{mimetype: "application/vnd.apache.arrow.stream", read_opts: [], write_opts: [compression: :zstd]}
    }
  end

  def facet_transformers_settings, do: %{scrobbles: %{transformer: Transformers.LocalFileArchiveTransformer}}

  def transformer(facet \\ :scrobbles, settings \\ facet_transformers_settings()), do: settings[facet][:transformer]
end
