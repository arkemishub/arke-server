 defmodule ArkeServer.OAuth.Provider.Apple do
   use ArkeServer.OAuth.Core
   alias Arke.Utils.DatetimeHandler, as: DatetimeHandler
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

   # verify the token validity based on: https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api/verifying_a_user
   def handle_request(%Plug.Conn{query_params: %{"token" => token, "nonce" => nonce}} = conn) do
     try do
       header = JOSE.JWT.peek_protected(token).fields

       with {:ok, jwk} <- get_public_key(header),
            {true, %JOSE.JWT{} = jwt, _jws} <- JOSE.JWT.verify(jwk, token),
            {:ok, data} <- validate_jwt(jwt, nonce) do
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
     {:error, msg} = Error.create(:auth, "token/nonce not found")

     Plug.Conn.assign(
       conn,
       :arke_server_oauth_failure,
       msg
     )
   end

   defp get_public_key(%{"kid" => certificate_id}) do
     # get pem certs to validate the token later
     case HTTPoison.get("https://appleid.apple.com/auth/keys") do
       {:ok, %{status_code: 200, body: body}} ->
         body = Poison.decode!(body)

         case Enum.find(body["keys"], nil, fn key -> key["kid"] == certificate_id end) do
           nil ->
             Error.create(:auth, "invalid token")

           key_cert ->
             {:ok, JOSE.JWK.from_map(key_cert)}
         end

       _ ->
         Error.create(:auth, "invalid token")
     end
   end

   defp get_public_key(token) do
     Error.create(:auth, "invalid token")
   end

   defp validate_jwt(token, nonce) do
     decoded = token.fields
     app_id = System.get_env("APPLE_CLIENT_ID", nil)

     with true <-
            String.contains?(Map.get(decoded, "iss", ""), "https://appleid.apple.com"),
          true <- Map.get(decoded, "aud", nil) == app_id,
          true <- Map.get(decoded, "nonce", nil) == nonce,
          true <-
            DatetimeHandler.from_unix(Map.get(decoded, "exp", 0)) > DatetimeHandler.now(:datetime) or
              Timex.from_unix(Map.get(decoded, "exp", 0)) > DatetimeHandler.now(:datetime) do
       {:ok, decoded}
     else
       _ -> Error.create(:auth, "invalid token")
     end
   end
 end
