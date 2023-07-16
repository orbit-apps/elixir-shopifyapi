if Code.ensure_loaded?(Ecto.ParameterizedType) do
  defmodule ShopifyAPI.ShopifyId.Ecto do
    @moduledoc """
    When Ecto is a dependency in the project, ShopifyId can be used as an Ecto parameterized type in a schema.

    ```elixir
    field :order_id, ShopifyAPI.ShopifyId, type: :order
    ```
    """
    defmacro __using__(_opts) do
      quote do
        use Ecto.ParameterizedType
      end
    end
  end
else
  defmodule ShopifyAPI.ShopifyId.Ecto do
    @moduledoc """
    When Ecto is a dependency in the project, ShopifyId can be used as an Ecto parameterized type in a schema.

    When Ecto is not a dependency, this is idnored.
    """
    defmacro __using__(_opts), do: nil
  end
end
