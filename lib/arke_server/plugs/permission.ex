# Copyright 2023 Arkemis S.r.l.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
defmodule ArkeServer.Plugs.Permission do
  import Plug.Conn
  alias ArkeAuth.Utils.Permission
  alias Arke.Utils.ErrorGenerator, as: Error
  alias ArkeServer.Utils.QueryFilters

  def init(default), do: default

  def call(%Plug.Conn{path_params: %{"arke_id"=> arke_id}} = conn, _default) do
    check_permission(conn,arke_id)
  end

  def call(%Plug.Conn{path_params: %{"group_id"=> group_id}} = conn, _default) do
    check_permission(conn,group_id)
    conn
  end
  def call(%Plug.Conn{path_params: %{"parameter_id"=> parameter_id}} = conn, _default) do
    check_permission(conn,parameter_id)
    conn
  end
  # handle arke_project and unit global search
  def call(%Plug.Conn{method: method,request_path: req_path} = conn, default) do
    regex = ~r{/lib/([^/]+)}
    arke_id =  Regex.run(regex, req_path) |> List.last()
   if is_nil(arke_id) do
    conn
    else
      check_permission(conn,arke_id)
      conn
    end
   end

  def call(conn,default), do: conn

  defp check_permission(%Plug.Conn{method: method}=conn,arke_id) do
    # todo: caipre cosa fare se arke_project non c'è,
    project = conn.assigns[:arke_project]
    action = parse_method(method)
    with {:ok,data} <- Permission.get_public_permission(arke_id, project),
          true <- is_permitted?(data,action) do
        assign(conn,:permission_filter,get_permission_filter(conn, data))
    else _ ->
    with %Plug.Conn{halted: false}=auth_conn <- ArkeServer.Plugs.AuthPipeline.call(conn,[]),
    {:ok,data} <- Permission.get_member_permission(ArkeAuth.Guardian.Plug.current_resource(auth_conn),arke_id, project),
         true <- is_permitted?(data,action) do
      assign(conn,:permission_filter,get_permission_filter(conn, data,ArkeAuth.Guardian.Plug.current_resource(auth_conn)))
    else
      %Plug.Conn{halted: true}=not_auth_conn -> not_auth_conn
      _ ->  {:error, msg} = Error.create(:auth, "unauthorized")
        ArkeServer.ResponseManager.send_resp(conn, 401, nil, msg)
        |> Plug.Conn.halt()
    end
    end
  end

  defp is_permitted?(permission,action), do: Map.get(permission, action, false)

  defp parse_method(method), do: String.downcase(method) |> String.to_atom()
  defp get_permission_filter(conn, %{filter: nil} = permission), do: permission

  defp get_permission_filter(conn,permission,member \\nil) do
    filter = String.replace(permission.filter, "{{arke_member}}", to_string(member.id))
    case QueryFilters.get_from_string(conn, filter) do
      {:ok, data} -> Map.put(permission, :filter, data)
      {:error, _msg} -> Map.put(permission, :filter, nil)
    end
  end

end