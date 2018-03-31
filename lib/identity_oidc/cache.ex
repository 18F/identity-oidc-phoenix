defmodule IdentityOidc.Cache do
  use Agent

  def start_link(_opts) do
    state = get_initial_state()
    Agent.start_link(fn -> state end, name: __MODULE__)
  end

  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  def get_all do
    Agent.get(__MODULE__, & &1)
  end

  defp get_initial_state do
    %{
      idp_sp_url: idp_sp_url,
      private_key_path: private_key_path
    } = Application.get_env(:identity_oidc, :oidc_config)

    with {:ok, well_known_config} <- IdentityOidc.get_well_known_configuration(idp_sp_url),
         {:ok, public_key} <- IdentityOidc.get_public_key(well_known_config["jwks_uri"]),
         private_key <- IdentityOidc.load_sp_private_key(private_key_path) do
      well_known_config
      |> string_keys_to_atoms()
      |> Map.put(:public_key, public_key)
      |> Map.put(:private_key, private_key)
    else
      {:error, error} -> %{error: error}
    end
  end

  defp string_keys_to_atoms(map) do
    map
    |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
    |> Map.new()
  end
end
