defmodule IdentityOidcWeb.Router do
  use IdentityOidcWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/", IdentityOidcWeb do
    # Use the default browser stack
    pipe_through(:browser)

    get("/", PageController, :index)
    get("/auth/oidc", PageController, :oidc)
    get("/auth/result", PageController, :result)
  end
end
