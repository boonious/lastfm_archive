defmodule LastfmArchive.Archive.Transformers.FileArchiveTransformerSettings do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def formats, do: available_formats()
      def mimetype(format), do: format_settings()[format][:mimetype]
      def read_opts(format), do: format_settings()[format][:read_opts]
      def write_opts(format), do: format_settings()[format][:write_opts]
      def setting(mimetype), do: format_settings() |> Enum.find(fn {_format, %{mimetype: type}} -> type == mimetype end)
    end
  end

  def available_formats, do: format_settings() |> Map.keys()

  def format_settings do
    %{
      csv: %{mimetype: "text/tab-separated-values", read_opts: [delimiter: "\t"], write_opts: [delimiter: "\t"]},
      parquet: %{mimetype: "application/vnd.apache.parquet", read_opts: [], write_opts: [compression: {:gzip, 9}]},
      ipc: %{mimetype: "application/vnd.apache.arrow.file", read_opts: [], write_opts: [compression: :zstd]},
      ipc_stream: %{mimetype: "application/vnd.apache.arrow.stream", read_opts: [], write_opts: [compression: :zstd]}
    }
  end
end
