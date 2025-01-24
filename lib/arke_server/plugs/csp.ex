defmodule ArkeServer.Plugs.ContentSecurityPolicy do
  import Plug.Conn

  def init(default), do: default

  def call(conn, _opts) do
    csp =
      "default-src 'self'; " <>
      "script-src 'self' cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.17.14/swagger-ui-bundle.js cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.17.14/swagger-ui-standalone-preset.js 'unsafe-inline';" <>
      "style-src 'self' cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.17.14/swagger-ui.css; 'unsafe-inline'" <>
      "frame-src 'none'; " <>
      "base-uri 'self'; " <>
      "form-action 'self'"

    conn
    |> put_resp_header("content-security-policy", csp)
  end
end
