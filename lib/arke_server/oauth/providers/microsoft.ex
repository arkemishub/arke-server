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

  def handle_request(%Plug.Conn{body_params: %{"access_token"=> access_token}} = conn) do
    with {:ok, data} <- verify_token(access_token) do
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

  defp verify_token(access_token) do
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
end
