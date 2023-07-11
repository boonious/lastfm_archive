defmodule LastfmArchive.Archive.Transformers.FileArchiveTransformerSettings do
  @moduledoc false

  defmacro __before_compile__(_env) do
    quote do
      def formats, do: mimetypes_opts() |> Map.keys()
      def mimetype(format), do: mimetypes_opts()[format] |> elem(0)

      def setting(format) when is_atom(format), do: mimetypes_opts()[format]
      def setting(mimetype), do: mimetypes_opts() |> Enum.find(fn {_format, {type, _opts}} -> type == mimetype end)

      defp mimetypes_opts do
        %{
          csv: {"text/tab-separated-values", [delimiter: "\t"]},
          parquet: {"application/vnd.apache.parquet", []}
        }
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end
end
