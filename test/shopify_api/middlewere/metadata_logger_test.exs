defmodule ShopifyAPI.Middleware.MetadataLoggerTest do
  use ExUnit.Case

  require Logger

  alias Exq.Middleware.Pipeline
  alias ShopifyAPI.EventPipe.Event
  alias ShopifyAPI.Middleware.MetadataLogger

  defp build_pipeline(args) when is_list(args) do
    %Pipeline{
      assigns: %{
        job: %{
          args: args
        }
      }
    }
  end

  defp build_pipeline(arg), do: build_pipeline([arg])

  test "Not metadata in the Event leads to no metadata in the Logger" do
    %Event{}
    |> build_pipeline
    |> MetadataLogger.before_work()

    assert Logger.metadata() == []
  end

  test "Metadata in the Event leads to metadata in the Logger" do
    request_id = "1234567890"

    %Event{metadata: %{request_id: request_id}}
    |> build_pipeline
    |> MetadataLogger.before_work()

    assert Logger.metadata() == [request_id: request_id]
  end

  test "A bunch of Metadata in the Event leads to metadata in the Logger" do
    request_id = "1234567890"
    meta1 = {:key, "value"}
    meta2 = [{:key, "value"}]

    %Event{metadata: %{request_id: request_id, meta1: meta1, meta2: meta2}}
    |> build_pipeline
    |> MetadataLogger.before_work()

    metadata = Logger.metadata()
    assert Keyword.get(metadata, :request_id) == request_id
    assert Keyword.get(metadata, :meta1) == meta1
    assert Keyword.get(metadata, :meta2) == meta2
  end
end
