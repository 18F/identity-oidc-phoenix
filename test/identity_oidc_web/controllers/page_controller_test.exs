defmodule IdentityOidcWeb.PageControllerTest do
  use IdentityOidcWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Login.gov Open ID Connect Phoenix"
  end

  describe "GET /auth/oidc" do
    test "with no authorization endpoint", %{conn: conn} do
      error_msg = "I am an error"

      IdentityOidc.Cache.init(%{error: error_msg})

      conn = get(conn, "/auth/oidc", acr_value: "foo")
      assert html_response(conn, 200) =~ error_msg
    end

    test "success", %{conn: conn} do
      authorization_endpoint = "http://foobar.com"

      IdentityOidc.Cache.init(%{authorization_endpoint: authorization_endpoint})

      acr_value = "foobar"

      conn = get(conn, "/auth/oidc", acr_value: acr_value)
      assert redirected_to(conn) =~ authorization_endpoint
    end
  end

  describe "GET /auth/result" do
    test "with bad params", %{conn: conn} do
      conn = get(conn, "/auth/result")
      assert html_response(conn, 200) =~ "missing callback param: code and/or state"
    end

    test "with error", %{conn: conn} do
      error_msg = "I am an error"
      conn = get(conn, "/auth/result", error: error_msg)
      assert html_response(conn, 200) =~ error_msg
    end
  end
end
