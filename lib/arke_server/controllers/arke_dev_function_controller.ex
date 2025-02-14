defmodule ArkeServer.ArkeDevFunctionController do
  use ArkeServer, :controller
  alias ArkeServer.ResponseManager

  def export_arke_db_stucture(conn, params) do
    project = Map.get(params, "project", "arke_system") |> String.to_atom()
    member = ArkeAuth.Guardian.get_member(conn)

    case member.arke_id do
      :super_admin ->
        ResponseManager.send_resp(
          conn,
          200,
          Arke.Utils.Export.get_db_structure(project, all: true)
        )

      _ ->
        ResponseManager.send_resp(conn, 401, nil)
    end
  end
end
