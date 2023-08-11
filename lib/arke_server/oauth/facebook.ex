defmodule ArkeServer.OAuth.Facebook do
  alias Arke.Utils.ErrorGenerator, as: Error

  def validate_token(token) do
    client_id = System.get_env("FACEBOOK_CLIENT_ID", nil)
    client_secret = System.get_env("FACEBOOK_CLIENT_SECRET", nil)
    query_params = %{"input_token" => token, "access_token" => "#{client_id}|#{client_secret}"}

    case HTTPoison.get("https://graph.facebook.com/v14.0/debug_token", [], params: query_params) do
      {:ok, %{status_code: 200, body: body}} ->
        body = Poison.decode!(body)

        case Map.get(body["data"], "app_id") == client_id and
               Map.get(body["data"], "is_valid", false) in ["true", "True", "1", true] do
          false ->
            Error.create(:auth, "invalid token")

          true ->
            get_user_data(token)
        end

      _ ->
        Error.create(:auth, "invalid token")
    end
  end

  defp get_user_data(token) do
    query_params = %{"fields" => "id,first_name,last_name,email", "access_token" => token}

    case HTTPoison.get("https://graph.facebook.com/v14.0/me", [], params: query_params) do
      {:ok, %{status_code: 200, body: body}} ->
        body = Poison.decode!(body)

        {:ok,
         %{
           uid: body["id"],
           provider: "facebook",
           info: %{
             first_name: body["first_name"],
             last_name: body["last_name"],
             email: body["email"]
           }
         }}

      _ ->
        Error.create(:auth, "invalid token")
    end
  end
end
