defmodule ArkeServer.OAuth.Provider.Microsoft do
  alias Arke.Utils.DatetimeHandler, as: DatetimeHandler

  use ArkeServer.OAuth.Core

  @private_oauth_key :arke_server_oauth

  def info(conn) do
    token_data = conn.private[@private_oauth_key]

    %UserInfo{
      first_name: token_data["givenName"],
      last_name: token_data["surname"],
      email: token_data["mail"]
    }

  end

  def uid(conn) do
    conn.private[@private_oauth_key]["id"]
  end

  def handle_cleanup(conn), do: put_private(conn, @private_oauth_key, nil)


  def handle_request(%Plug.Conn{body_params: %{"id_token" => token, "access_token"=> access_token}} = conn) do
    with {:ok, claims} <- verify_token(token),
         {:ok, data} <- get_user_data(access_token) do
      put_private(conn, @private_oauth_key, data)
    else
      {:error, msg} ->
        Plug.Conn.assign(
          conn,
          :arke_server_oauth_failure,
          msg
        )
    end
  end

  def handle_request(conn) do
    {:error, msg} = Error.create(:auth, "token not found")
    Plug.Conn.assign(
      conn,
      :arke_server_oauth_failure,
      msg
    )
  end

  defp get_user_data(access_token) do
    url = "https://graph.microsoft.com/v1.0/me"
    headers = [{"Authorization", "Bearer #{access_token}"}]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Failed to verify token, status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp verify_token(token) do
    with {:ok, claims} <- decode_and_verify(token),
         :ok <- validate_claims(claims) do
      {:ok, claims}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp decode_and_verify(token) do
    jwt = JOSE.JWT.peek(token)
    case validate_signature(token) do
      :ok -> {:ok, jwt.fields}
      {:error, reason} -> {:error, reason}
    end

  end

  defp validate_signature(jwt) do
    case get_public_keys() do
      {:ok, keys} ->
        Enum.find_value(keys, {:error, "Invalid signature"}, fn key ->
          if JOSE.JWT.verify(key, jwt) do
            :ok
          end
        end)

      {:error, reason} -> {:error, reason}
    end
  end

  defp get_public_keys do
    uri = "https://login.microsoftonline.com/#{get_key("AZURE_TENANT_ID")}/discovery/v2.0/keys"
    case HTTPoison.get(uri) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        keys = body |> Jason.decode!() |> Map.get("keys")
        {:ok, Enum.map(keys, &JOSE.JWK.from(&1))}

      {:error, %HTTPoison.Error{reason: reason}} -> {:error, reason}
    end
  end

  defp validate_claims(claims) do
    cond do
      claims["iss"] != "https://login.microsoftonline.com/#{get_key("AZURE_TENANT_ID")}/v2.0" -> {:error, "Invalid issuer"}
      claims["tid"] != get_key("AZURE_TENANT_ID") -> {:error, "Invalid tenant"}
      DatetimeHandler.from_unix(Map.get(claims, "exp", 0)) < DatetimeHandler.now(:datetime) -> {:error, "Token expired"}
      true -> :ok
    end
  end

  defp get_key(key), do: System.get_env(key, nil)
end
