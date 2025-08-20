defmodule ShopifyAPI.GraphQL.TelemetryLogger do
  @doc """
  A basic implementation of logging for GraphQLQuery

  In your `application.ex` add `ShopifyAPI.GraphQL.TelemetryLogger.attach()`
  """
  require Logger

  alias ShopifyAPI.GraphQL.GraphQLResponse

  def handle_event([:shopify_api, :graphqlquery, :start], _measurements, metadata, _config) do
    Logger.info("ShopifyAPI.GraphQL.start #{metadata.query.name}", details(metadata))
  end

  def handle_event(
        [:shopify_api, :graphqlquery, :stop],
        measurements,
        %{response: %GraphQLResponse{errors?: false}} = metadata,
        _config
      ) do
    Logger.info(
      "ShopifyAPI.GraphQL.stop #{metadata.query.name} finished in #{measurements.duration}",
      details(metadata)
    )
  end

  def handle_event(
        [:shopify_api, :graphqlquery, :stop],
        measurements,
        %{response: %GraphQLResponse{errors?: true}} = metadata,
        _config
      ) do
    Logger.info(
      "ShopifyAPI.GraphQL.stop #{metadata.query.name} finished with errors in #{measurements.duration}, #{inspect(metadata.response.errors)}#{inspect(metadata.response.errors)}",
      details(metadata)
    )
  end

  def handle_event(
        [:shopify_api, :graphqlquery, :stop],
        measurements,
        %{error: exception} = metadata,
        _config
      ) do
    Logger.info(
      "ShopifyAPI.GraphQL.stop #{metadata.query.name} failed with exception in #{measurements.duration}, #{inspect(exception)}",
      details(metadata)
    )
  end

  def handle_event([:shopify_api, :graphqlquery, :exception], _measurements, metadata, _config) do
    Logger.error(
      "ShopifyAPI.GraphQL.exception #{metadata.query.name} #{metadata.kind} #{inspect(metadata.reason)} #{Exception.format_stacktrace(metadata.stacktrace)}",
      details(metadata)
    )
  end

  defp details(metadata) do
    myshopify_domain = ShopifyAPI.Scopes.myshopify_domain(metadata.scope)

    [
      query: metadata.query.name,
      myshopify_domain: myshopify_domain
    ]
  end

  def attach do
    :telemetry.attach_many(
      "shopifyapi-graphql-request",
      [
        [:shopify_api, :graphqlquery, :start],
        [:shopify_api, :graphqlquery, :stop],
        [:shopify_api, :graphqlquery, :exception]
      ],
      &handle_event/4,
      nil
    )
  end
end
