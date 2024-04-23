defmodule ArkeServer.HealthController do
  use ArkeServer, :controller
  alias ArkeServer.ResponseManager

  def ready(conn,_params) do
    ResponseManager.send_resp(conn,200,nil)
  end
end