defmodule LastfmArchive.Behaviour.DataFrameIo do
  @moduledoc """
  Behaviour, macro and functions for Explorer.DataFrame related I/Os.
  """

  import LastfmArchive.Archive.Transformers.TransformerConfigs

  @type data :: String.t() | binary()
  @type data_frame :: Explorer.DataFrame.t()
  @type filepath :: String.t()
  @type options :: Keyword.t()

  for format <- formats() do
    @callback unquote(:"dump_#{format}!")(data_frame(), options()) :: data()
    @callback unquote(:"to_#{format}!")(data_frame(), filepath(), options()) :: :ok
    @callback unquote(:"from_#{format}!")(filepath(), options()) :: data_frame()
  end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour LastfmArchive.Behaviour.DataFrameIo
      @data_frame_io Application.compile_env(:lastfm_archive, :data_frame_io, Explorer.DataFrame)

      for format <- Keyword.get(opts, :formats, formats()) do
        @impl true
        defdelegate unquote(:"dump_#{format}!")(data_frame, options), to: @data_frame_io

        @impl true
        defdelegate unquote(:"to_#{format}!")(data_frame, filepath, options), to: @data_frame_io

        @impl true
        defdelegate unquote(:"from_#{format}!")(filepath, options), to: @data_frame_io

        defoverridable [{:"dump_#{format}!", 2}, {:"to_#{format}!", 3}, {:"from_#{format}!", 2}]
      end
    end
  end
end
