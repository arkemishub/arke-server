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

defmodule ArkeServer.GroupController do
  @moduledoc """
            Documentation for `ArkeServer.ParameterController`
  """
  use ArkeServer, :controller

  # Openapi request definition
  use ArkeServer.Openapi.Spec, module: ArkeServer.Openapi.GroupControllerSpec

  alias Arke.{QueryManager, LinkManager, StructManager}
  alias Arke.Core.Unit
  alias Arke.Boundary.{ArkeManager, GroupManager}
  alias ArkeServer.ResponseManager
  alias ArkeServer.Utils.{QueryFilters, QueryOrder}

  alias ArkeServer.Openapi.Responses

  alias OpenApiSpex.{Operation, Reference}

  @doc """
  Call Group function
  """
  def call_group_function(conn, %{"group_id" => group_id, "function_name" => function_name}) do
    project = conn.assigns[:arke_project]
    permission = conn.assigns[:permission_filter] || %{filter: nil}

    group =
      GroupManager.get(group_id, project)
      |> Arke.Core.Unit.update(runtime_data: %{conn: conn})

    case GroupManager.call_func(group, String.to_atom(function_name), [group]) do
      {:file, file, filename} ->
        send_download(conn, {:binary, file}, filename: filename)

      {:error, error, status} ->
        ResponseManager.send_resp(conn, status, nil, error)

      {:error, error} ->
        ResponseManager.send_resp(conn, 404, nil, error)

      {:ok, content, status} ->
        ResponseManager.send_resp(conn, status, %{content: content})

      {:ok, content, status, messages} ->
        ResponseManager.send_resp(conn, status, %{content: content}, messages)

      res ->
        ResponseManager.send_resp(conn, 200, %{content: res})
    end
  end

  # get the group struct
  def struct(conn, %{"group_id" => group_id}) do
    project = conn.assigns[:arke_project]
    arke = ArkeManager.get(:arke, :arke_system)
    group = GroupManager.get(String.to_existing_atom(group_id), project)
    parameters = GroupManager.get_parameters(group)

    tmp_arke =
      Unit.load(arke,
        label: group.data.label,
        parameters: parameters,
        metadata: %{project: project}
      )

    struct = StructManager.get_struct(tmp_arke, conn.query_params)
    ResponseManager.send_resp(conn, 200, %{content: struct})
  end

  ## get all the arke in the given group
  def get_arke(conn, %{"group_id" => group_id}) do
    project = conn.assigns[:arke_project]

    case GroupManager.get(String.to_existing_atom(group_id), project) do
      {:error, msg} ->
        ResponseManager.send_resp(conn, 404, nil)

      group ->
        ResponseManager.send_resp(conn, 200, %{
          items: StructManager.encode(GroupManager.get_arke_list(group), type: :json)
        })
    end
  end

  ## get all the units of the arke inside the given group
  def get_unit(conn, %{"group_id" => group_id}) do
    project = conn.assigns[:arke_project]
    member = ArkeAuth.Guardian.get_member(conn, true)
    permission = conn.assigns[:permission_filter] || %{filter: nil}
    offset = Map.get(conn.query_params, "offset", nil)
    limit = Map.get(conn.query_params, "limit", nil)
    order = Map.get(conn.query_params, "order", [])

    load_links = Map.get(conn.query_params, "load_links", "false") == "true"
    load_values = Map.get(conn.query_params, "load_values", "false") == "true"
    load_files = Map.get(conn.query_params, "load_files", "false") == "true"

    {count, units} =
      QueryManager.query(project: project)
      |> QueryManager.filter(:group_id, :eq, group_id, false)
      |> QueryFilters.apply_query_filters(Map.get(conn.assigns, :filter))
      |> QueryFilters.apply_query_filters(permission.filter)
      |> QueryFilters.apply_member_child_only(member, Map.get(permission, :child_only, false))
      |> QueryOrder.apply_order(order)
      |> QueryManager.pagination(offset, limit)

    ResponseManager.send_resp(conn, 200, %{
      count: count,
      items:
        StructManager.encode(units,
          load_links: load_links,
          load_values: load_values,
          load_files: load_files,
          type: :json
        )
    })
  end

  # get the detail of the unit in the given group id based on the unit_id
  def unit_detail(conn, %{"group_id" => group_id, "unit_id" => unit_id}) do
    project = conn.assigns[:arke_project]
    permission = conn.assigns[:permission_filter] || %{filter: nil}
    member = ArkeAuth.Guardian.get_member(conn)

    load_links = Map.get(conn.query_params, "load_links", "false") == "true"
    load_values = Map.get(conn.query_params, "load_values", "false") == "true"
    load_files = Map.get(conn.query_params, "load_files", "false") == "true"

    unit =
      QueryManager.query(project: project)
      |> QueryManager.filter(:group_id, :eq, group_id, false)
      |> QueryManager.filter(:id, :eq, unit_id, false)
      |> QueryFilters.apply_query_filters(Map.get(conn.assigns, :filter))
      |> QueryFilters.apply_query_filters(permission.filter)
      |> QueryFilters.apply_member_child_only(member, Map.get(permission, :child_only, false))
      |> QueryManager.one()

    ResponseManager.send_resp(conn, 200, %{content: StructManager.encode(unit, type: :json)})
  end
end
