use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :identity_oidc, IdentityOidcWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :identity_oidc, :cache, preload: false

config :identity_oidc, :oidc_config, %{
  idp_sp_url: "http://localhost:3000",
  acr_values: [
    "http://idmanagement.gov/ns/assurance/loa/1",
    "http://idmanagement.gov/ns/assurance/loa/3"
  ],
  redirect_uri: "http://localhost:4000/",
  client_id: "urn:gov:gsa:openidconnect:sp:phoenix",
  private_key_path: "config/demo_sp.key"
}
