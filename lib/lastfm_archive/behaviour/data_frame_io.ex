defmodule LastfmArchive.Behaviour.DataFrameIo do
  @moduledoc """
  Behaviour, macro and functions for Explorer.DataFrame related I/Os.
  """

  import LastfmArchive.Archive.Transformers.FileArchiveTransformerSettings

  @type data :: String.t() | binary()
  @type data_frame :: Explorer.DataFrame.t()
  @type filepath :: String.t()
  @type options :: Keyword.t()

  for format <- available_formats() do
    @callback unquote(:"dump_#{format}!")(data_frame(), options()) :: data()
    @callback unquote(:"to_#{format}!")(data_frame(), filepath(), options()) :: :ok
    @callback unquote(:"from_#{format}!")(filepath(), options()) :: data_frame()
  end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour LastfmArchive.Behaviour.DataFrameIo
      import LastfmArchive.Behaviour.DataFrameIo

      @data_frame_io Application.compile_env(:lastfm_archive, :data_frame_io, Explorer.DataFrame)

      for format <- Keyword.fetch!(opts, :formats) do
        @impl true
        defdelegate unquote(:"dump_#{format}!")(data_frame, options), to: @data_frame_io

        @impl true
        defdelegate unquote(:"to_#{format}!")(data_frame, filepath, options), to: @data_frame_io

        @impl true
        defdelegate unquote(:"from_#{format}!")(filepath, options), to: @data_frame_io

        defoverridable [{:"dump_#{format}!", 2}, {:"to_#{format}!", 3}, {:"from_#{format}!", 2}]

        def dump_data_frame(df, unquote(format), opts) do
          apply(__MODULE__, :"dump_#{unquote(format)}!", [df, opts])
        end

        def to_data_frame(df, filepath, unquote(format), opts) do
          apply(__MODULE__, :"to_#{unquote(format)}!", [df, filepath, opts])
        end

        def load_data_frame(filepath, unquote(format), opts) do
          apply(__MODULE__, :"from_#{unquote(format)}!", [filepath, opts])
        end
      end
    end
  end
end
