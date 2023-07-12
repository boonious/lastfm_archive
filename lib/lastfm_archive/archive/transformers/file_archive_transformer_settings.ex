defmodule LastfmArchive.Archive.Transformers.FileArchiveTransformerSettings do
  @moduledoc false

  @format_settings Application.compile_env!(:lastfm_archive, :file_archive_transformer)[:format_settings]
  @available_formats @format_settings |> Map.keys()

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def formats, do: available_formats()
      def mimetype(format), do: format_settings()[format] |> elem(0)

      def setting(format) when is_atom(format), do: format_settings()[format]
      def setting(mimetype), do: format_settings() |> Enum.find(fn {_format, {type, _opts}} -> type == mimetype end)
    end
  end

  def available_formats, do: @available_formats
  def format_settings, do: @format_settings
end
