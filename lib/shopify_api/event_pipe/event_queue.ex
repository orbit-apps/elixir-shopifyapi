defmodule ShopifyAPI.EventPipe.EventQueue do
  @doc """
  Event enqueue end point, takes the event and the options to be passed on to Exq.

  options: [max_retries: #] or any Exq valid enqueue option.
  """

  def subscribe(token) do
    background_job_impl().subscribe(token)
  end

  defp background_job_impl do
    Application.get_env(
      :shopify_api,
      :background_job_implementation,
      ShopifyAPI.EventPipe.InlineBackgroundJob
    )
  end
end
