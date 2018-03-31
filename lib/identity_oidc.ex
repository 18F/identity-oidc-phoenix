defmodule IdentityOidc do
  @moduledoc """
  IdentityOidc keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  use HTTPoison.Base

  def get_well_known_configuration(idp_sp_url) do
    uri = uri_join(idp_sp_url, "/.well-known/openid-configuration")

    case get(uri) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Sorry, could not fetch well known configuration: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Sorry, could not fetch well known configuration: #{reason}"}
    end
  end

  def get_public_key(jwks_uri) do
    case get(jwks_uri) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body |> Map.fetch!("keys") |> List.first()}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Sorry, could not fetch public_key: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Sorry, could not fetch public_key: #{reason}"}
    end
  end

  def build_authorization_url(client_id, acr_values, redirect_uri, authorization_endpoint) do
    query = [
      client_id: client_id,
      response_type: "code",
      acr_values: acr_values,
      scope: "openid email",
      redirect_uri: uri_join(redirect_uri, "/auth/result"),
      state: random_value(),
      nonce: random_value(),
      prompt: "select_account"
    ]

    authorization_endpoint <> "?" <> URI.encode_query(query)
  end

  def build_jwt(client_id, token_endpoint, private_key) do
    claims = %{
      iss: client_id,
      sub: client_id,
      aud: token_endpoint,
      jti: random_value(),
      nonce: random_value(),
      exp: DateTime.to_unix(DateTime.utc_now()) + 1000
    }

    Joken.token(claims)
    |> Joken.sign(Joken.rs256(private_key))
    |> Joken.get_compact()
  end

  def exchange_code_for_token(code, token_endpoint, jwt) do
    body = %{
      grant_type: "authorization_code",
      code: code,
      client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
      client_assertion: jwt
    }

    case post(token_endpoint, body, [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        %{"id_token" => id_token, "access_token" => access_token} = body
        {:ok, id_token, access_token}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Sorry, could not exchange code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Sorry, could not exchange code: #{reason}"}
    end
  end

  def load_sp_private_key(private_key_path) do
    JOSE.JWK.from_pem_file(private_key_path)
  end

  def decode_jwt(id_token, public_key) do
    Joken.token(id_token)
    |> Joken.verify!(Joken.rs256(public_key))
    |> elem(1)
  end

  def get_user_info(userinfo_endpoint, access_token) do
    case get(userinfo_endpoint, [{"Authorization", "Bearer " <> access_token}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Sorry, could not fetch userinfo: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Sorry, could not fetch userinfo: #{reason}"}
    end
  end

  def build_logout_uri(id_token, end_session_endpoint, redirect_uri) do
    end_session_endpoint <>
      "?" <>
      URI.encode_query(
        id_token_hint: id_token,
        post_logout_redirect_uri: redirect_uri,
        state: random_value()
      )
  end

  defp random_value do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  defp uri_join(uri, path) do
    URI.merge(uri, path) |> URI.to_string()
  end

  defp process_request_body(body) do
    Poison.encode!(body)
  end

  defp process_response_body(body) do
    Poison.decode!(body)
  end
end
