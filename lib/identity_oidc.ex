defmodule IdentityOidc do
  @moduledoc """
  IdentityOidc keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def openid_configuration do
    case IdentityOidc.get_well_known_configuration() do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        config = Poison.decode!(body)
        {:ok, IdentityOidc.build_authorization_url(config)}

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:error, IdentityOidc.unauthorized_error()}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, IdentityOidc.other_error(status_code)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, IdentityOidc.other_error(reason)}
    end
  end

  # TODO - cache
  def get_well_known_configuration do
    HTTPoison.get(get_config(:idp_sp_url) <> "/.well-known/openid-configuration")
  end

  def build_authorization_url(%{"authorization_endpoint" => authorization_endpoint}) do
    query =
      URI.encode_query(
        client_id: get_config(:client_id),
        response_type: "code",
        acr_values: get_config(:acr_values),
        scope: "openid email",
        redirect_uri: get_config(:redirect_uri) <> "/auth/result",
        state: random_value(),
        nonce: random_value(),
        prompt: "select_account"
      )

    authorization_endpoint <> "?" <> query
  end

  def unauthorized_error do
    """
    Error: #{get_config(:idp_sp_url)} responded with 401.
    Check basic authentication in IDP_USER and IDP_PASSSWORD environment variables.
    """
  end

  def other_error(reason) do
    "Error: #{get_config(:idp_sp_url)} responded with #{reason}."
  end

  def result(code) do
    with {:ok, %HTTPoison.Response{status_code: 200, body: config}} <-
           IdentityOidc.get_well_known_configuration(),
         %{
           "token_endpoint" => token_endpoint,
           "jwks_uri" => jwks_uri,
           "end_session_endpoint" => end_session_endpoint
         } <- Poison.decode!(config),
         id_token <- IdentityOidc.get_token!(code, token_endpoint),
         userinfo <- IdentityOidc.userinfo!(id_token, jwks_uri) do
      {userinfo, IdentityOidc.logout_uri(id_token, end_session_endpoint)}
    end
  end

  # token_endpoint = "http://localhost:3000/api/openid_connect/token"
  # code = "fafa6a5e-d41e-42a9-a47b-ef714e611add"
  # id_token =
  #   "eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiI2NDRmZDQ1MC1mYjQ0LTQ0NzktYWExOS00MzVlYWFiOGFlYzAiLCJpc3MiOiJodHRwOi8vbG9jYWxob3N0OjMwMDAvIiwiZW1haWwiOiJkYXZpZC5jb3J3aW4rMUBnc2EuZ292IiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImFjciI6Imh0dHA6Ly9pZG1hbmFnZW1lbnQuZ292L25zL2Fzc3VyYW5jZS9sb2EvMSIsIm5vbmNlIjoiZDVlN2U2ZmY4MWU1OWM2ODQzMDZmODVmNzg5N2Q2ZTQiLCJhdWQiOiJ1cm46Z292OmdzYTpvcGVuaWRjb25uZWN0OnNwOnNpbmF0cmEiLCJqdGkiOiJYaTR2WUxzMldSNTVEQkVmTFRfMVN3IiwiYXRfaGFzaCI6ImRDRTFVS2dCVTVGTGpTNGo3WTQ5OEEiLCJjX2hhc2giOiI2dU4wR1BWTzlZLTFCRzVpM3dMVkNRIiwiZXhwIjoxNTIyMjUxMTc3LCJpYXQiOjE1MjIyNTA2NDEsIm5iZiI6MTUyMjI1MDY0MX0.pqH9V_I-S6dJf7uumE3Hr9_ImLBd5QsFYDJk96bv0PmuRD0o_-iO9rRD-FtdyTT3oGH19gFr7h4Z4xftYDusXYZBMVayHT-9WWjzTO4fZ_x0TdLkfkIEHnzMS7wqRZEE8doBGd12oRvR9E6Ilh4iRIixEmu7e1EtxqbJVmWo9tg-78LU_J7LN_e52A-ut1F9f6OowOodOImsF8yY0_HcIj1EETNbziWRMuLjh7u8uRNh9cvIX2KMLNDK7XwY4ddsMksRAS1OwR84QlKcMZ-vF2P9CgTHXq4yYBa6fwWRQwRSkuZfrCSbndNxCcmoq-dunZdqBy_CFvI1UKuvU0MKWA"
  # jwks_uri = "http://localhost:3000/api/openid_connect/certs"
  # end_session_endpoint = "http://localhost:3000/openid_connect/logout"
  # {"code" => "fafa6a5e-d41e-42a9-a47b-ef714e611add", "state" => "b2005afa6735d28884a500436a36921b"}
  def get_token!(code, token_endpoint) do
    HTTPoison.post!(
      token_endpoint,
      Poison.encode!(%{
        grant_type: "authorization_code",
        code: code,
        client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
        client_assertion: IdentityOidc.client_assertion_jwt(token_endpoint)
      }),
      [{"Content-Type", "application/json"}]
    )
    |> Map.fetch!(:body)
    |> Poison.decode!()
    |> Map.fetch!("id_token")
  end

  def client_assertion_jwt(token_endpoint) do
    client_id = get_config(:client_id)

    claims = %{
      iss: client_id,
      sub: client_id,
      aud: token_endpoint,
      jti: random_value(),
      nonce: random_value(),
      exp: DateTime.to_unix(DateTime.utc_now()) + 1000
    }

    Joken.token(claims)
    |> Joken.sign(Joken.rs256(sp_private_key()))
    |> Joken.get_compact()
  end

  # TODO - cache
  def sp_private_key do
    JOSE.JWK.from_pem_file("config/demo_sp.key")
  end

  def userinfo!(id_token, jwks_uri) do
    public_key = idp_public_key(jwks_uri)

    Joken.token(id_token)
    |> Joken.with_signer(Joken.rs256(public_key))
    |> Joken.verify!()
    |> elem(1)
  end

  def idp_public_key(jwks_uri) do
    jwks_uri
    |> HTTPoison.get!()
    |> Map.fetch!(:body)
    |> Poison.decode!()
    |> Map.fetch!("keys")
    |> List.first()
  end

  def logout_uri(id_token, end_session_endpoint) do
    end_session_endpoint <>
      "?" <>
      URI.encode_query(
        id_token_hint: id_token,
        post_logout_redirect_uri: get_config(:redirect_uri),
        state: random_value()
      )
  end

  defp get_config(key) do
    get_config()[key]
  end

  defp get_config do
    Application.get_env(:identity_oidc, :oidc_config)
  end

  defp random_value do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end
end
