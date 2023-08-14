defmodule ArkeServer.OAuth.Provider.Facebook do
  use ArkeServer.OAuth.Core

  @private_oauth_key :arke_server_oauth

  def info(conn) do
    token_data = conn.private[@private_oauth_key]

    %UserInfo{
      first_name: token_data["first_name"],
      last_name: token_data["last_name"],
      email: token_data["email"]
    }
  end

  def uid(conn) do
    conn.private[@private_oauth_key]["id"]
  end

  def handle_cleanup(conn), do: put_private(conn, @private_oauth_key, nil)

  def handle_request(%Plug.Conn{query_params: %{"token" => token}} = conn) do
    client_id = System.get_env("FACEBOOK_CLIENT_ID", nil)
    client_secret = System.get_env("FACEBOOK_CLIENT_SECRET", nil)
    query_params = %{"input_token" => token, "access_token" => "#{client_id}|#{client_secret}"}

    case HTTPoison.get("https://graph.facebook.com/v14.0/debug_token", [], params: query_params) do
      {:ok, %{status_code: 200, body: body}} ->
        body = Poison.decode!(body)

        case Map.get(body["data"], "app_id") == client_id and
               Map.get(body["data"], "is_valid", false) in ["true", "True", "1", true] do
          false ->
            Plug.Conn.assign(
              conn,
              :arke_server_oauth_failure,
              Error.create(:auth, "invalid token")
            )

          true ->
            get_user_data(conn, token)
        end

      _ ->
        Plug.Conn.assign(
          conn,
          :arke_server_oauth_failure,
          Error.create(:auth, "invalid token")
        )
    end
  end

  defp get_user_data(conn, token) do
    query_params = %{"fields" => "id,first_name,last_name,email", "access_token" => token}

    case HTTPoison.get("https://graph.facebook.com/v14.0/me", [], params: query_params) do
      {:ok, %{status_code: 200, body: body}} ->
        body = Poison.decode!(body)

        put_private(conn, @private_oauth_key, body)

      _ ->
        Plug.Conn.assign(
          conn,
          :arke_server_oauth_failure,
          Error.create(:auth, "invalid token")
        )
    end
  end
end
