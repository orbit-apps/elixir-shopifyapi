# Local development

## Getting Started

### 1. Setup ngrok

We use ngrok to tunnel public requests to localhost endpoints for testing.

1.  Download ngrok app and create an ngrok account.
2.  Run the "Connect your account" terminal command to set your authtoken.

    ```sh
      ./ngrok authtoken ExampleCHANGEmeTOtheREALdealOk
    ```

3.  After account creation, go to the dashboard, click "Reserved".
4.  Add new reserved domain to make it simpler to access your domain.
    `https://geneparmesan.ngrok.io`
5.  Run ngrok from the command line and start the process:
    `$ ./ngrok http -subdomain=geneparmesan 4000`

### 2. Create new Shopify app

Use the Shopify Partners dashboard to create new app to test against.

- Log in to https://partners.shopify.com
- Apps > Create App
- Fill in with generic info
- When App open, click App Info
- Use your ngrok URL as the App URL. eg: `https://geneparmesan.ngrok.io`
- Under "Whitelisted redirection URL(s)" add your ngrok URL, but append `/shop/authorized`, like so: `https://geneparmesan.ngrok.io/shop/authorized`
- Click Save button (top-right)
- Notice your "API key" and "API secret key" further down the page, we will be using these in the next step.

### 3. Create or use existing Shopify dev store

Create a use another Development store to test against, this is the store that you wish to use the app with.

- Remember the URI for your development store: `geneparmesan-pi.myshopify.com`

### 4. Create a new local dev config in project

We need to create a new local dev config file to use to test against.

```sh
# Navigate your project directory in your terminal.

# Create local config file `config/dev.local.exs`, or copy sample file
$ cp config/dev.sample.exs dev.local.exs
```

```elixir
# Update config/dev.local.exs from to match your store URI and your app's API and secret key.

config :shopify_api, ShopifyApi.Shop, %{
  "<SHOP_URL>.myshopify.com" => %{
    domain: "<SHOP_URL>.myshopify.com"
  }
}

config :shopify_api, ShopifyApi.App, %{
  "<APP_NAME>" => %{
    name: "<APP_NAME>",
    client_id: "<APP_API_key>",
    client_secret: "<APP_secret_key>",
    auth_redirect_uri: "https://geneparmesan.ngrok.io/shop/authorized/<APP_NAME>"
    nonce: "test"
  }
}
```

### 5. Install the app

Now, launch the Phoenix server and start running.

```sh
$ mix phx.server
```

### 6. Visit the install URL

```sh
$ open http://localhost:4000/shop/install?shop=<SHOP_URL>.myshopify.com&app=<APP_NAME>
```
