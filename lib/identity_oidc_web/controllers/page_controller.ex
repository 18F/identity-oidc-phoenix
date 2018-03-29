defmodule IdentityOidcWeb.PageController do
  use IdentityOidcWeb, :controller

  def index(conn, _params) do
    case IdentityOidc.openid_configuration() do
      {:ok, authorization_url} ->
        render(conn, "index.html", authorization_url: authorization_url)

      {:error, error} ->
        render(conn, "errors.html", error: error)
    end
  end

  def result(conn, %{"code" => code}) do
    {userinfo_response, logout_uri} = IdentityOidc.result(code)

    render(
      conn,
      "success.html",
      userinfo: userinfo_response,
      logout_uri: logout_uri
    )
  end

  def result(conn, %{"error" => error}) do
    render(conn, "errors.html", error: error)
  end

  def result(conn, _params) do
    render(conn, "errors.html", error: "missing callback param: code")
  end
end
