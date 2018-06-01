# Local development

## Getting Started

### 1. Setup ngrok

We use ngrok to tunnel public requests to locahost endpoints for testing.

1.  Download ngrok app.
2.  Create an account, sign up with your PXU Google account.
3.  Run the "Connect your account" terminal command to set your authtoken.


    ```sh
      ./ngrok authtoken ExampleCHANGEmeTOtheREALdealOk
    ```

4.  After account creation, go to the dashboard, click "Reserved".
5.  Add new reserved domain to make it simplier to access your domain.
    `http://geneparmesan.ngrok.io`
6.  Run ngrok from the command line and start the process:
    `$ ./ngrok http -subdomain=geneparmesan 4000`

### 2. Create new Shopify app

Use the Shopify Partners dashboard to create new app to test against.

- Log in to https://partners.shopify.com
- Apps > Create App
- Fill in with generic info
- When App open, click App Info
- Use your ngrok URL as the App url. eg: `http://geneparmesan.ngrok.io`
- Under "Whitelisted redirection URL(s)" add your ngrok URL, but append `/shop/authorized`, like so: `http://geneparmesan.ngrok.io/shop/authorized`
- Click Save button (top-right)
- Notice your "API key" and "API secret key" further down the page, we will be using these in the next step.

### 3. Create or use exisiting Shopify dev store

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
  "store.myshopify.com" => %{
    domain: "store.myshopify.com"
  }
}

config :shopify_api, ShopifyApi.App, %{
  "testapp" => %{
    name: "testapp",
    client_id: "<APP_API_key>",
    client_secret: "<APP_secret_key>",
    auth_redirect_uri: "http://hez1.ngrok.io/shop/authorized/testapp"
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
$ open http://localhost:4000/shop/install?shop=<SHOP-URL>.myshopify.com&app=<APP-NANE>
```