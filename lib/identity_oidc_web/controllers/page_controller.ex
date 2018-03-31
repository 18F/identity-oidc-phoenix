defmodule IdentityOidcWeb.PageController do
  use IdentityOidcWeb, :controller

  def index(conn, _params) do
    %{
      client_id: client_id,
      acr_values: acr_values,
      redirect_uri: redirect_uri
    } = Application.get_env(:identity_oidc, :oidc_config)

    case IdentityOidc.Cache.get_all() do
      %{authorization_endpoint: authorization_endpoint} ->
        authorization_url =
          IdentityOidc.build_authorization_url(
            client_id,
            acr_values,
            redirect_uri,
            authorization_endpoint
          )

        render(conn, "index.html", authorization_url: authorization_url)

      {:error, error} ->
        render(conn, "errors.html", error: error)
    end
  end

  def result(conn, %{"code" => code, "state" => _state}) do
    %{
      client_id: client_id,
      redirect_uri: redirect_uri
    } = Application.get_env(:identity_oidc, :oidc_config)

    %{
      end_session_endpoint: end_session_endpoint,
      token_endpoint: token_endpoint,
      private_key: private_key,
      public_key: public_key,
      userinfo_endpoint: _userinfo_endpoint
    } = IdentityOidc.Cache.get_all()

    with jwt <- IdentityOidc.build_jwt(client_id, token_endpoint, private_key),
         {:ok, id_token, _access_token} <-
           IdentityOidc.exchange_code_for_token(code, token_endpoint, jwt),
         userinfo <- IdentityOidc.decode_jwt(id_token, public_key),
         logout_uri <- IdentityOidc.build_logout_uri(id_token, end_session_endpoint, redirect_uri) do
      render(conn, "success.html", userinfo: userinfo, logout_uri: logout_uri)
    else
      {:error, error} ->
        render(conn, "errors.html", error: error)
    end
  end

  def result(conn, %{"error" => error}) do
    render(conn, "errors.html", error: error)
  end

  def result(conn, _params) do
    render(conn, "errors.html", error: "missing callback param: code and/or state")
  end
end
