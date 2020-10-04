defmodule ShopifyAPI.Router do
  use Plug.Router

  alias ShopifyAPI.{Authorizer}

  plug(:match)
  plug(:dispatch)

  #  `/start/:app`
  #   The first step in the OAuth process... All requests start here.
  #
  #   In this portion of the request, we ensure the request is valid (to the best of our
  #   abilities) and then redirect the request back to Shopify so that they can finalize the
  #   OAuth permission flow.
  #
  #   As a part of this, we provide Shopify a redirect url to come back to based on whether
  #   this is the first time we're receiving a request for the shop, or if this is a request for a
  #   shop whose credentials are already installed.
  #
  #   Once Shopify has authorized the request, they use the redirect we've provided to make a
  #   request to the appropriate endpoint (either /install/:app or /run/:app based on shop state
  #   in our system).
  #
  #   From there, we handle that secondary request according to the rules for that endpoint.
  #
  #   ## Configuration
  #    Shopify will need to have a way to reach your app during the OAuth process & so you'll
  #    need to let Shopify know how to do this. Unfortunately, this is not something that can be
  #    handled dynamically or via introspection; this needs to be set up statically in a couple of
  #    places: both in the Shopify Settings for your app and in the ShopifyAPI library settings.
  #
  #    There's two parts to getting this route set up.
  #
  #    1. You'll need to set up the full url to the location of the ShopifyAPI /start/:app
  #        endpoint in the `App URL` configuration text field in the `URLs` section of the
  #        Shopify Partners `Apps` interface.
  #    2. The ShopifyAPI library will also need to know where it lives on the Internet. This will
  #        require letting ShopifyAPI know the web URL that it has been mounted to in your
  #        Phoenix routes.
  #
  #    For example, if we had our app named `best_app_evah` added to ShopifyAPI and  hosted
  #   at `https://muh-app.ngrok.io/` and we configured our Phoenix routes to forward requests
  #   going to `/shop` to the ShopifyAPI App router, then we'd set `App URL`
  #   in the Shopify App Setup interface to be `https://muh-app.ngrok.io/shop/start/best_app_evah`
  #   and we'd configure our Elixir app to look something like:
  #
  #    In order to let ShopifyAPI know where it lives, we use the ShopifyApi.Authorizer uri
  #    configuration directive.
  #
  #  ### Example
  #  ```elixir
  #    config :shopify_api, ShopifyAPI.Authorizer,
  #         uri: "https://muh-app.ngrok.io/app"
  #  ```
  #
  #  *note -- this Elixir app configuration needs only happen once. It will be available for all
  #  apps once it is set in your application; however, each application you install will need to
  #  have it's analog Shopify App configuration updated to reflect where ShopifyAPI is available
  #  on the Internet.
  get "/start/:app" do
    Authorizer.authorize_request(conn)
  end

  #  `/install/:app`
  #   Install the Shop credentials into the app.
  #
  #   This is the path that Shopify will hit once the user authorizes the app in the Shopify app
  #   interface. This is the route used when ShopifyAPI library installs the shop credentials
  #   locally.
  #
  #   This should only be used once -- at the time of shop credential installation. Once the shop
  #    credentials have been installed, this path should no longer be used, but rather, the
  #    /run/:app path will be used after Shopify OAuth process has returned control to your
  #    app.
  #
  #   ## Configuration
  #
  #    This route requires analog configuration in the Shopify App setup interface under the
  #    `URLs` section. The full URL to the `/install/:app` endpoint will need to be added to
  #     the list of `Allowed Redirection URL(s)`
  #
  #   For example, if we had our app named `best_app_evah` added to ShopifyAPI and  hosted
  #   at `https://muh-app.ngrok.io/` and we configured our Phoenix routes to forward requests
  #   going to `/shop` to the ShopifyAPI App router, then we'd add
  #   `https://muh-app.ngrok.io/shop/install/best_app_evah` to the list of `Allowed Redirection
  #   URL(s)` in the Shopify App Setup interface.
  #
  #   In addition to setting up the `/install/:app` endpoint as a valid redirection URL, you'll
  #   likely want to configure some behavior to occur after the installation has completed.
  #   ShopifyAPI includes a hook to allow you to customize the behavior of the library once
  #   it has completed the installation process.
  #
  #   You can customize the behavior that occurs after the Shop credentials are installed by
  #   setting the `ShopifyApi.Authorizer post_install` callback hook in your application
  #   configuration.
  #
  #   ### Example
  #   For example, if you wanted to show a specific page after install completes, set your
  #   application config with something like this:
  #
  #  ```elixir
  #  config :shopify_api, ShopifyAPI.Authorizer,
  #         post_install: {MuhAppWeb.AppController, :do_post_install}
  #  ```
  #
  #  In this example, we've let ShopifyAPI know that we want to run the `do_post_install`
  #  function in the `MuhAppWeb.AppController` module once the installation has completed.
  #
  #  The function you point to should be able to handle a Plug.Conn connection as its only
  #  argument. Normally, this would be handled in a Phoenix controller in your Phoenix app.
  #
  #  The function definition for the configuration above might look something like:
  #
  #  ```elixir
  #  defmodule MuhAppWeb.AppController do
  #    def do_post_install(conn) do
  #      conn
  #      |> put_view(MuhAppWeb.AppView)
  #      |> render("post_install.html")
  #      |> halt()
  #      end
  #    end
  #  ```
  #  *note -- this Elixir app configuration needs only happen once. It will be available for all
  #  apps once it is set in your application; however, each application you install will need to
  #  have it's analog Shopify App configuration updated to reflect where ShopifyAPI is available
  #  on the Internet.
  get "/install/:app" do
    Authorizer.install_app(conn)
  end

  #  `/run/:app`
  #   Load and run the app.
  #
  #  This is the path that Shopify will use for normal day-to-day usage of your app.
  #
  #   ## Configuration
  #
  #    This route requires analog configuration in the Shopify App setup interface under the
  #    `URLs` section. The full URL to the `/run/:app` endpoint will need to be added to the
  #    list of `Allowed Redirection URL(s)`
  #
  #   For example, if we had our app named `best_app_evah` added to ShopifyAPI and  hosted
  #   at `https://muh-app.ngrok.io/` and we configured our Phoenix routes to forward requests
  #   going to `/shop` to the ShopifyAPI App router, then we'd add
  #   `https://muh-app.ngrok.io/shop/run/best_app_evah` to the list of `Allowed Redirection
  #   URL(s)` in the Shopify App Setup interface.
  #
  #   In addition to setting up the `/run/:app` endpoint as a valid redirection URL, you'll likely
  #    want to configure some behavior to occur after authorization has completed and Shopify
  #    returns control of the OAuth flow to your app. ShopifyAPI includes some hooks to allow
  #    you to customize the behavior of the library once it has completed the authorization
  #    process.
  #
  #   You can customize the behavior that occurs after the request has been authorized by
  #   setting the `ShopifyApi.Authorizer run_app` callback hook in your application configuration.
  #
  #   ### Example
  #   For example, to load up the application once auth has completed, set your application
  #   config with something like this:
  #
  #  ```elixir
  #  config :shopify_api, ShopifyAPI.Authorizer,
  #         run_app: {MuhAppWeb.AppController, :run_my_app}
  #  ```
  #
  #  In this example, we've let ShopifyAPI know that we want to run the `run_my_app`
  #  function in the `MuhAppWeb.AppController` module once authorization has completed.
  #
  #  The function you point to should be able to handle a Plug.Conn connection as its only
  #  argument. Normally, this would be handled in a Phoenix controller in your Phoenix app.
  #
  #  The function definition for the configuration above might look something like:
  #
  #  ```elixir
  #  defmodule MuhAppWeb.AppController do
  #    def run_my_app(conn) do
  #      conn
  #      |> put_view(MuhAppWeb.AppView)
  #      |> render("my_app.html")
  #      |> halt()
  #      end
  #    end
  #  ```
  get "/run/:app" do
    Authorizer.run_app(conn)
  end
end
