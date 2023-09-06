defmodule ShopifyAPI.ShopifyId do
  @moduledoc """
  Holds A Shopify Id or Global Id.

  Sometimes shopify gives you an Id that looks like
  `"gid://shopify/Order/1234567890000"` from one place, and `"1234567890000"` from another, and `1234567890000` from another, to reference the same object.

  https://shopify.dev/docs/api/usage/gids

  This aims to reduce the confusion, around shopify ids and allow for convenient typspecs and guards.

  ## With Ecto

  ShopifyId can be used in a schema with:
  ```elixir
  field :order_id, ShopifyAPI.ShopifyId, type: :order
  ```

  ## With Absinthe

  ShopifyId can be used as an Absinthe custom type with:
  ```elixir
    defmodule MyAppGraphQL.Schema.CustomTypes do
      use Absinthe.Schema.Notation

      alias Wishlist.ShopifyAPI.ShopifyId
      alias Absinthe.Blueprint.Input

      scalar :shopify_customer_id, name: "ShopifyCustomerId" do
        description("The `CustomerId` scalar type represents a shopify customer id.")

        serialize(&ShopifyId.stringify/1)
        parse(&parse_shopify_customer_id/1)
      end

      @spec parse_shopify_customer_id(Input.String.t()) :: {:ok, ShopifyId.t(:customer)} | :error
      @spec parse_shopify_customer_id(Input.Integer.t()) :: {:ok, ShopifyId.t(:customer)} | :error
      @spec parse_shopify_customer_id(Input.Null.t()) :: {:ok, nil}
      defp parse_shopify_customer_id(%Input.String{value: value}), do: ShopifyId.new(value, :customer)

      defp parse_shopify_customer_id(%Input.Integer{value: value}),
        do: ShopifyId.new(value, :customer)

      defp parse_shopify_customer_id(%Input.Null{}), do: {:ok, nil}
    end
  ```

  """

  @type t(object_type) :: %__MODULE__{
          object_type: object_type,
          id: String.t()
        }

  @type t() :: t(atom())

  @enforce_keys [:object_type, :id]
  defstruct @enforce_keys

  @spec new(String.t() | integer(), object_type) :: {:ok, t(object_type)} | :error
        when object_type: atom()
  def new("gid://shopify/" <> rest, type) when is_atom(type) do
    with [object_type, id] <- String.split(rest, "/"),
         ^type <- atomize_type(object_type) do
      new(id, type)
    else
      _ -> :error
    end
  end

  def new(id, type) when is_integer(id) and is_atom(type),
    do: id |> Integer.to_string() |> new(type)

  def new(id, type) when is_binary(id) and is_atom(type),
    do: {:ok, %__MODULE__{object_type: type, id: id}}

  @spec new!(String.t() | integer(), object_type) :: t(object_type) when object_type: atom()
  def new!(id, type) do
    case new(id, type) do
      {:ok, shopify_id} -> shopify_id
      :error -> raise ArgumentError, message: "type does not match shopify id"
    end
  end

  def atomize_type(object_type) when is_binary(object_type),
    do: object_type |> Macro.underscore() |> String.to_existing_atom()

  def deatomize_type(type) when is_atom(type), do: type |> Atom.to_string() |> Macro.camelize()

  def stringify(%__MODULE__{object_type: object_type, id: id}),
    do: "gid://shopify/" <> deatomize_type(object_type) <> "/" <> id

  ###################
  # Implementations
  ###################

  defimpl Jason.Encoder do
    alias ShopifyAPI.ShopifyId

    def encode(shopify_id, opts),
      do: shopify_id |> ShopifyId.stringify() |> Jason.Encode.string(opts)
  end

  ###################
  # Ecto ParameterizedType Callbacks
  #
  # Only used if Ecto is a dependency.
  ###################

  use ShopifyAPI.ShopifyId.Ecto

  @impl true
  def type(_params), do: :string

  @impl true
  def init(opts) do
    type = Keyword.fetch!(opts, :type)
    %{type: type}
  end

  @impl true
  def cast(gid, %{type: type}) when is_binary(gid), do: new(gid, type)
  def cast(%__MODULE__{object_type: type} = shopify_id, %{type: type}), do: {:ok, shopify_id}
  def cast(nil, _params), do: {:ok, nil}
  def cast(_, _params), do: :error

  @impl true
  def load(data, _loader, %{type: type}) when is_binary(data), do: new(data, type)
  def load(nil, _loader, _params), do: {:ok, nil}

  @impl true
  def dump(shopify_id, _dumper, _params) when is_struct(shopify_id, __MODULE__),
    do: {:ok, stringify(shopify_id)}

  def dump(nil, _dumper, _params), do: {:ok, nil}
  def dump(_, _dumper, _params), do: :error
end
