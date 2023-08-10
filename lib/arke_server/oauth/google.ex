defmodule ArkeServer.OAuth.Google do
  alias Arke.Utils.ErrorGenerator, as: Error
  alias Arke.DatetimeHandler, as: DatetimeHandler

  def validate_token(token) do
    try do
      header = JOSE.JWT.peek_protected(token).fields

      with {:ok, jwk} <- get_certs(header),
           {true, %JOSE.JWT{} = jwt, _jws} <- JOSE.JWT.verify(jwk, token),
           {:ok, data} <-
             validate_jwt(jwt) do
        {:ok,
         %{
           uid: data["sub"],
           provider: "google",
           info: %{
             first_name: data["given_name"],
             last_name: data["family_name"],
             email: data["email"]
           }
         }}
      else
        {:error, msg} -> {:error, msg}
      end
    rescue
      _ -> Error.create(:auth, "invalid token")
    end
  end

  defp get_certs(%{"kid" => certificate_id}) do
    # get pem certs to validate the token later
    case HTTPoison.get("https://www.googleapis.com/oauth2/v1/certs") do
      {:ok, %{status_code: 200, body: body}} ->
        body = Poison.decode!(body)

        case Map.get(body, certificate_id, nil) do
          nil ->
            Error.create(:auth, "invalid token")

          pem_cert ->
            {:ok, JOSE.JWK.from_pem(pem_cert)}
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
