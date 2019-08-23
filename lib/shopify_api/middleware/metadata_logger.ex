defmodule ShopifyAPI.Middleware.MetadataLogger do
  @moduledoc """
  Applies the metadata stored the Event to the Logger's metadata for logging within Exq middleware
  """

  @behaviour Exq.Middleware.Behaviour

  require Logger

  alias Exq.Middleware.Pipeline

  def before_work(%Pipeline{assigns: %{job: %{args: args}}} = pipeline) do
    Enum.each(args, &apply_metadata/1)
    pipeline

    # TODO assigns.job.jid
  end

  defp apply_metadata(%{metadata: metadata = %{}}) do
    metadata
    |> Enum.into([])
    |> Logger.metadata()
  end

  defp apply_metadata(_event), do: nil

  def after_processed_work(pipeline), do: pipeline
  def after_failed_work(pipeline), do: pipeline
end
