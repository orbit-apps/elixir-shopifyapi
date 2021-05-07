defmodule ShopifyAPI.ShopUnavailableError do
  defexception message: "Shop Unavailable"
end

defmodule ShopifyAPI.ShopNotFoundError do
  defexception message: "Shop Not Found"
end

defmodule ShopifyAPI.ShopAuthError do
  defexception message: "Invalid API key"
end
