defmodule Fixtures.Archive do
  @moduledoc false

  def solr_add_docs(), do: File.read!("test/fixtures/solr_add_docs.json")
  def solr_schema_response(), do: File.read!("test/fixtures/solr_schema_response.json")
  def solr_missing_fields_response(), do: File.read!("test/fixtures/solr_missing_fields_response.json")
end
