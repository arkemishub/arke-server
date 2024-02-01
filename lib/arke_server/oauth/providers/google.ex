defmodule ArkeServer.OAuth.Provider.Google do
  alias Arke.Utils.DatetimeHandler, as: DatetimeHandler

  use ArkeServer.OAuth.Core

  @private_oauth_key :arke_server_oauth

  def info(conn) do
    token_data = conn.private[@private_oauth_key]

    %UserInfo{
      first_name: token_data["given_name"],
      last_name: token_data["family_name"],
      email: token_data["email"]
    }
  end

  def uid(conn) do
    conn.private[@private_oauth_key]["sub"]
  end

  def handle_cleanup(conn), do: put_private(conn, @private_oauth_key, nil)

  def handle_request(%Plug.Conn{query_params: %{"token" => token}} = conn) do
    try do
      header = JOSE.JWT.peek_protected(token).fields

      with {:ok, jwk} <- get_certs(header),
           {true, %JOSE.JWT{} = jwt, _jws} <- JOSE.JWT.verify(jwk, token),
           {:ok, data} <- validate_jwt(jwt) do
        put_private(conn, @private_oauth_key, data)
      else
        {:error, msg} ->
          Plug.Conn.assign(
            conn,
            :arke_server_oauth_failure,
            msg
          )
      end
    rescue
      _ ->
        Plug.Conn.assign(
          conn,
          :arke_server_oauth_failure,
          Error.create(:auth, "invalid token")
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

  defp get_certs(%{"kid" => certificate_id}) do
    # get pem certs to validate the token later
    case HTTPoison.get("https://www.googleapis.com/oauth2/v3/certs") do
      {:ok, %{status_code: 200, body: body}} ->
        body = Poison.decode!(body)

        case Enum.find(body["keys"], nil, fn k -> k["kid"] == certificate_id end) do
          nil ->
            Error.create(:auth, "invalid token")

          key_cert ->
            {:ok, JOSE.JWK.from_map(key_cert)}
        end

      _ ->
        Error.create(:auth, "invalid token")
    end
  end

  defp get_certs(_token), do: Error.create(:auth, "invalid token")

  # check if the token is valid based on: https://developers.google.com/identity/gsi/web/guides/verify-google-id-token
  defp validate_jwt(token) do
    decoded = token.fields
    app_id = System.get_env("GOOGLE_CLIENT_ID", nil)

    with true <-
           Map.get(decoded, "iss", nil) in ["https://accounts.google.com", "accounts.google.com"],
         true <- Map.get(decoded, "aud", nil) == app_id,
         true <-
           DatetimeHandler.from_unix(Map.get(decoded, "exp", 0)) > DatetimeHandler.now(:datetime) do
      {:ok, decoded}
    else
      _ -> Error.create(:auth, "invalid token")
    end
  end
end
