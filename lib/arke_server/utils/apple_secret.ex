defmodule ArkeServer.Utils.Apple do
  require Logger
  @expiration_sec 86400 * 180

  @spec client_secret(keyword) :: String.t()
  def client_secret(_config \\ []) do
    UeberauthApple.generate_client_secret(%{
      # client_id  matches the reverse-domain Services ID registered with Apple.
      client_id: System.get_env("APPLE_CLIENT_ID"),
      expires_in: @expiration_sec,
      key_id: System.get_env("APPLE_PRIVATE_KEY_ID"),
      team_id: System.get_env("APPLE_TEAM_ID"),
      # private_key could be the certificate as string """---start--- .... ----end---""" or the path to the file
      private_key: handle_private_key(System.get_env("APPLE_PRIVATE_KEY"))
    })
  end

  defp handle_private_key(nil), do: nil

  defp handle_private_key(path) do
    case File.read(path) do
      {:ok, string} ->
        string

      {:error, msg} ->
        Logger.error("invalid file for `APPLE_PRIVATE_KEY`")
        {:error, msg}
    end
  end
end
