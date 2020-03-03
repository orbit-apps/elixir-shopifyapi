defmodule ShopifyAPI.RateLimiting.Tracker do
  alias ShopifyAPI.AuthToken

  @type available_count :: integer()
  @type availability_delay :: integer()
  @type t :: {available_count(), availability_delay()}

  @callback init :: any()
  @callback all :: list()
  @callback api_hit_limit(AuthToken.t(), HTTPoison.Response.t(), DateTime.t()) :: t()
  @callback update_api_call_limit(AuthToken.t(), HTTPoison.Response.t()) :: t()
  @callback get(AuthToken.t(), DateTime.t(), integer()) :: t()
  @callback set(AuthToken.t(), available_count(), availability_delay(), DateTime.t()) :: t()
end
