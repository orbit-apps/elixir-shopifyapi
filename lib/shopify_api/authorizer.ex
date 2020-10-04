defmodule ShopifyAPI.Authorizer do
  require Logger

  alias Plug.Conn

  alias ShopifyAPI.{
    App,
    AuthToken,
    AuthTokenServer,
    Config,
    ConnHelpers,
    Shop,
    ShopifyAuthRequest,
    ShopServer
  }

  @spec authorize_request(Plug.Conn.t()) :: Plug.Conn.t()
  def authorize_request(conn) do
    Logger.debug(
      "#{__MODULE__} received initialization request for " <>
        "shop: #{ConnHelpers.shop_domain(conn)} " <>
        "app: #{ConnHelpers.app_name(conn)}"
    )

    if app_installed_in_shop?(conn),
      do: authorize_run_request(conn),
      else: initialize_installation(conn)
  end

  @spec app_installed_in_shop?(Plug.Conn.t()) :: boolean()
  def app_installed_in_shop?(conn) do
    shop_domain = ConnHelpers.shop_domain(conn)

    found =
      case ShopServer.get(shop_domain) do
        {:ok, _} -> true
        :error -> false
      end

    Logger.debug(
      "#{__MODULE__} determining if app is already installed in shop '#{shop_domain} -- #{found}'"
    )

    found
  end

  @spec authorize_run_request(Plug.Conn.t()) :: Plug.Conn.t()
  def authorize_run_request(conn) do
    Logger.debug(
      "#{__MODULE__} app already installed in shop. Authorizing request with shopify " <>
        "shop: #{ConnHelpers.shop_domain(conn)} " <>
        "app: #{ConnHelpers.app_name(conn)}"
    )

    case generate_authorization_uri(conn) do
      {:ok, auth_uri} ->
        redirect_to_shopify_auth(conn, auth_uri)

      {:error, res} ->
        Logger.info("#{__MODULE__} failed to run with: #{res}")
        halt_install(conn)
    end
  end

  @spec initialize_installation(Plug.Conn.t()) :: Plug.Conn.t()
  def initialize_installation(conn) do
    case generate_install_uri(conn) do
      {:ok, install_uri} ->
        redirect_to_shopify_auth(conn, install_uri)

      {:error, res} ->
        Logger.info("#{__MODULE__} failed install with: #{res}")
        halt_install(conn)
    end
  end

  defp generate_authorization_uri(%Plug.Conn{} = conn) do
    case ConnHelpers.fetch_shopify_app(conn) do
      {:ok, app} ->
        Logger.debug("#{__MODULE__} fetched shopify app #{app.name}")
        generate_authorization_uri(conn, app)

      _ ->
        Logger.error("#{__MODULE__} unable to fetch shopify app #{ConnHelpers.app_name(conn)}")
        {:error, "unable to fetch shopify app"}
    end
  end

  defp generate_authorization_uri(conn, app) do
    Logger.debug("#{__MODULE__} fetched shopify app #{app.name}")
    domain = ConnHelpers.shop_domain(conn)

    case post_auth_redirect_uri(app, domain) do
      {:ok, redirect_uri} ->
        auth_uri = ShopifyAuthRequest.generate_auth_uri(app, domain, redirect_uri)
        {:ok, auth_uri}

      {:error, _resp} ->
        msg =
          "Unable to find a configured authorization redirect URI. " <>
            "Please configure an authorization redirect URI using the ShopifyAPI.Authorizer.uri " <>
            "Configuration directive, or set up the ShopifyAPI.App run_uri callback. See the " <>
            "ShopifyAPI readme for more information."

        Logger.error(msg)
        raise msg
    end
  end

  defp generate_install_uri(%Plug.Conn{} = conn) do
    case ConnHelpers.fetch_shopify_app(conn) do
      {:ok, app} ->
        Logger.debug("#{__MODULE__} fetched shopify app #{app.name}")
        generate_install_uri(conn, app)

      _ ->
        Logger.error("#{__MODULE__} unable to fetch shopify app #{ConnHelpers.app_name(conn)}")
        {:error, "unable to fetch shopify app"}
    end
  end

  defp generate_install_uri(conn, app) do
    domain = ConnHelpers.shop_domain(conn)

    case post_install_redirect_uri(app, domain) do
      {:ok, redirect_uri} ->
        auth_uri = ShopifyAuthRequest.generate_auth_uri(app, domain, redirect_uri)
        {:ok, auth_uri}

      {:error, _resp} ->
        msg =
          "Unable to find a configured installation redirect URI. " <>
            "Please configure an installation redirect URI using the ShopifyAPI.Authorizer.uri " <>
            "Configuration directive, or set up the ShopifyAPI.App install_uri callback. See the " <>
            "ShopifyAPI readme for more information."

        Logger.error(msg)
        raise msg
    end
  end

  @spec post_auth_redirect_uri(ShopifyAPI.App.t(), binary()) ::
          {:ok, binary()} | {:error, binary()}
  defp post_auth_redirect_uri(app, domain) do
    conf = Application.get_env(:shopify_api, ShopifyAPI.Authorizer)
    base_uri = if is_list(conf), do: conf[:uri], else: nil

    case base_uri do
      nil ->
        generate_auth_redirect_from_app(app, domain)

      base ->
        generate_redirect_from_uri(base, "run", app.name)
    end
  end

  @spec post_install_redirect_uri(ShopifyAPI.App.t(), binary()) ::
          {:ok, binary()} | {:error, binary()}
  defp post_install_redirect_uri(app, domain) do
    conf = Application.get_env(:shopify_api, ShopifyAPI.Authorizer)
    base_uri = if is_list(conf), do: conf[:uri], else: nil

    case base_uri do
      nil ->
        generate_install_redirect_from_app(app, domain)

      base_uri ->
        generate_redirect_from_uri(base_uri, "install", app.name)
    end
  end

  defp generate_redirect_from_uri(base, type, app_name) do
    case base do
      b when is_binary(b) ->
        redirect = "#{base}/#{type}/#{app_name}"
        Logger.debug("#{__MODULE__} uri configured. using #{redirect} for redirect uri")
        {:ok, redirect}

      _ ->
        {:error, "invalid base. Cannot generate redirect."}
    end
  end

  defp generate_auth_redirect_from_app(app, domain) do
    case Config.lookup(ShopifyAPI.App, :run_uri) do
      redirect when is_binary(redirect) ->
        Logger.debug("#{__MODULE__} generated authorization uri for #{domain} = #{redirect}")
        {:ok, redirect}

      nil ->
        app.auth_redirect_uri

      _ ->
        {:error, "No App auth redirection uri defined"}
    end
  end

  defp generate_install_redirect_from_app(app, domain) do
    case Config.lookup(ShopifyAPI.App, :install_uri) do
      redirect when is_binary(redirect) ->
        Logger.debug("#{__MODULE__} generated authorization uri for #{domain} = #{redirect}")
        {:ok, redirect}

      nil ->
        app.auth_redirect_uri

      _ ->
        {:error, "No App install redirection uri defined"}
    end
  end

  @spec install_app(Plug.Conn.t()) :: Plug.Conn.t()
  def install_app(conn) do
    case authorize_shop(conn) do
      {:ok, _resp} ->
        run_post_install(conn)

      {:error, _msg} ->
        halt_install(conn)
    end
  end

  @spec run_app(Plug.Conn.t()) :: Plug.Conn.t()
  def run_app(conn) do
    case authorize_shop(conn) do
      {:ok, _resp} ->
        run_post_auth(conn)

      {:error, _msg} ->
        halt_install(conn)
    end
  end

  @spec authorize_shop(Plug.Conn.t()) :: {:ok, any()} | {:error, any()}
  def authorize_shop(conn) do
    case ConnHelpers.fetch_shopify_app(conn) do
      {:ok, app} ->
        update_token_for(conn, app)

      _ ->
        Logger.debug("#{__MODULE__}  app #{ConnHelpers.app_name(conn)} not found")
        {:error, "unable to fetch app"}
    end
  end

  defp run_post_auth(conn) do
    case Config.lookup(__MODULE__, :run_app) do
      {module, function} -> apply(module, function, [conn])
      {module, function, _args} -> apply(module, function, [conn])
      _ -> render_authenticated_response(conn)
    end
  end

  defp run_post_install(conn) do
    case Config.lookup(__MODULE__, :post_install) do
      {module, function} -> apply(module, function, [conn])
      {module, function, _args} -> apply(module, function, [conn])
      _ -> render_installed_response(conn)
    end
  end

  defp update_token_for(conn, app) do
    if valid_auth_request?(conn, app) do
      Logger.debug("#{__MODULE__} Authorized #{ConnHelpers.shop_domain(conn)}")
      config_auth_token(conn, app)
    else
      Logger.debug("#{__MODULE__} invalid request for #{ConnHelpers.shop_domain(conn)}. halting.")
      {:error, "invalid auth request received"}
    end
  end

  defp valid_auth_request?(conn, app) do
    nonce_verified = ConnHelpers.verify_nonce(app, conn.query_params)
    params_verified = ConnHelpers.verify_params_with_hmac(app, conn.query_params)
    shop_name_verified = ConnHelpers.verify_shop_name(ShopifyAPI.ConnHelpers.shop_domain(conn))

    Logger.debug(
      "request: nonce: #{nonce_verified} params: #{params_verified} " <>
        "shop_name: #{shop_name_verified} " <>
        "shop domain: #{ShopifyAPI.ConnHelpers.shop_domain(conn)}"
    )

    nonce_verified && params_verified && shop_name_verified
  end

  defp config_auth_token(conn, app) do
    case request_permanent_token(conn, app) do
      {:ok, auth_token} ->
        save_auth_token(auth_token)
        save_shop(conn)
        run_shop_post_install_callback(auth_token)
        {:ok, "authorized"}

      {:error, resp} ->
        {:error, "unable to fetch auth_token #{inspect(resp)}"}
    end
  end

  defp save_auth_token(%AuthToken{} = token) do
    AuthTokenServer.set(token)
  end

  defp save_shop(conn) do
    ShopServer.set(%Shop{domain: ConnHelpers.shop_domain(conn)})
  end

  defp run_shop_post_install_callback(%AuthToken{} = auth_token) do
    Shop.post_install(auth_token)
  end

  defp request_permanent_token(conn, app) do
    shop_domain = ConnHelpers.shop_domain(conn)
    app_name = ConnHelpers.app_name(conn)
    auth_code = ConnHelpers.auth_code(conn)
    timestamp = String.to_integer(conn.query_params["timestamp"])

    Logger.debug(
      "#{__MODULE__} requesting permanent token shop: #{shop_domain}  app: #{app_name}"
    )

    app
    |> App.fetch_token(shop_domain, auth_code)
    |> case do
      {:ok, token} ->
        Logger.debug(
          "#{__MODULE__} successfully fetched permanent token " <>
            "shop: #{shop_domain} app: #{app_name}"
        )

        {:ok,
         %AuthToken{
           app_name: app_name,
           shop_name: shop_domain,
           code: auth_code,
           timestamp: timestamp,
           token: token
         }}

      msg ->
        Logger.error(
          "#{__MODULE__} unable to fetch permanent token shop: #{shop_domain} " <>
            "app: #{app_name} #{inspect(msg)}"
        )

        {:error, "unable to fetch token"}
    end
  end

  defp render_authenticated_response(conn) do
    shop_domain = ConnHelpers.shop_domain(conn)
    Logger.debug("#{__MODULE__} rendering authenticated response for #{shop_domain}")

    conn
    |> Conn.resp(
      200,
      "Authenticated. <p>Update <ul><pre>config :shopify_api, ShopifyAPI.Authorizer, " <>
        "run_app: {MyAppWeb.AppController, :run_app} </pre></ul> to configure. See ShopifyAPI " <>
        "README for more information</p>"
    )
    |> Conn.halt()
  end

  defp render_installed_response(conn) do
    shop_domain = ConnHelpers.shop_domain(conn)
    Logger.debug("#{__MODULE__} rendering authenticated response for #{shop_domain}")

    conn
    |> Conn.resp(
      200,
      "Authenticated. <p>Update <ul><pre>config :shopify_api, ShopifyAPI.Authorizer, " <>
        "post_install: {MyAppWeb.AppController, :post_install} </pre></ul> to configure. See " <>
        "ShopifyAPI README for more information</p>"
    )
    |> Conn.halt()
  end

  defp redirect_to_shopify_auth(conn, uri) do
    Logger.debug(
      "#{__MODULE__} redirecting to shopify to complete auth for " <>
        "#{ConnHelpers.shop_domain(conn)} to #{uri}"
    )

    conn
    |> Conn.put_resp_header("location", uri)
    |> Conn.resp(unquote(302), "You are being redirected.")
    |> Conn.halt()
  end

  defp halt_install(conn) do
    shop_domain = ConnHelpers.shop_domain(conn)
    Logger.info("#{__MODULE__} halting installation of #{shop_domain}")

    conn
    |> Conn.resp(404, "Not Found.")
    |> Conn.halt()
  end
end
