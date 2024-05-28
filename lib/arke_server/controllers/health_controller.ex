defmodule ArkeServer.HealthController do
  use ArkeServer, :controller
  alias ArkeServer.ResponseManager

  # Endpoint useful for readiness probe
  def ready(conn,_params) do
    ResponseManager.send_resp(conn,200,nil)
  end

  # Endpoint useful for liveness probe
  def live(conn,_params) do
    ResponseManager.send_resp(conn,200,nil)
  end

  # Endpoint useful for startup probe
  def start(conn,_params) do
    ResponseManager.send_resp(conn,200,nil)
  end
end