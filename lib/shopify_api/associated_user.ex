defmodule ShopifyAPI.AssociatedUser do
  @derive {Jason.Encoder,
           only: [
             :id,
             :first_name,
             :last_name,
             :email,
             :email_verified,
             :account_owner,
             :locale,
             :collaborator
           ]}
  defstruct id: 0,
            first_name: "",
            last_name: "",
            email: "",
            email_verified: false,
            account_owner: false,
            locale: "",
            collaborator: false

  @typedoc """
  Type that represents a Shopify Associated User
  """
  @type t :: %__MODULE__{
          id: integer(),
          first_name: String.t(),
          last_name: String.t(),
          email: String.t(),
          email_verified: boolean(),
          account_owner: boolean(),
          locale: String.t(),
          collaborator: boolean()
        }

  @spec from_auth_request(map()) :: t()
  def from_auth_request(params) do
    %__MODULE__{
      id: params["id"],
      first_name: params["first_name"],
      last_name: params["last_name"],
      email: params["email"],
      email_verified: params["email_verified"],
      account_owner: params["account_owner"],
      locale: params["locale"],
      collaborator: params["collaborator"]
    }
  end
end
