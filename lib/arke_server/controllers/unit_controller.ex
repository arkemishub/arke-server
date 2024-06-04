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

defmodule ArkeServer.UnitController do
  use ArkeServer, :controller

  # Openapi request definition
  use ArkeServer.Openapi.Spec, module: ArkeServer.Openapi.UnitControllerSpec

  alias Arke.{QueryManager, LinkManager, StructManager}
  alias Arke.Boundary.{ArkeManager, ParameterManager}
  alias UnitSerializer
  alias ArkeServer.ResponseManager
  alias ArkeServer.Utils.{QueryFilters, QueryOrder}

  alias(ArkeServer.Openapi.Responses)
  alias OpenApiSpex.{Operation, Reference}

  import ArkeServer.ArkeController, only: [data_as_klist: 1]

  @doc """
  Search units
  """
  def search(conn, %{}) do
    project = conn.assigns[:arke_project]
    offset = Map.get(conn.query_params, "offset", 0)
    limit = Map.get(conn.query_params, "limit", 100)
    order = Map.get(conn.query_params, "order", [])

    {count, units} =
      QueryManager.query(project: project)
      |> QueryFilters.apply_query_filters(Map.get(conn.assigns, :filter))
      |> QueryOrder.apply_order(order)
      |> QueryManager.pagination(offset, limit)

    ResponseManager.send_resp(conn, 200, %{
      count: count,
      items: StructManager.encode(units, type: :json)
    })
  end

  @doc """
  Update an unit
  """
  def update(%Plug.Conn{body_params: params} = conn, %{
        "unit_id" => _unit_id,
        "arke_id" => _arke_id
      }) do
    project = conn.assigns[:arke_project]
    # TODO handle query parameter with plugs
    load_links = Map.get(conn.query_params, "load_links", "false") == "true"
    load_values = Map.get(conn.query_params, "load_values", "false") == "true"

    QueryManager.update(conn.assigns[:unit], data_as_klist(params))
    |> case do
      {:ok, unit} ->
        ResponseManager.send_resp(conn, 200, %{
          content:
            StructManager.encode(unit,
              load_links: load_links,
              load_values: load_values,
              type: :json
            )
        })

      {:error, error} ->
        ResponseManager.send_resp(conn, 400, nil, error)
    end
  end

  @doc """
  Update units in bulk
  """
  def update_bulk(%Plug.Conn{body_params: params} = conn, %{
        "arke_id" => id
      }) do
    project = conn.assigns[:arke_project]
    # TODO handle query parameter with plugs
    load_links = Map.get(conn.query_params, "load_links", "false") == "true"
    load_values = Map.get(conn.query_params, "load_values", "false") == "true"

    arke = ArkeManager.get(String.to_atom(id), project)

    permission = conn.assigns[:permission_filter] || %{filter: nil}
    member = ArkeAuth.Guardian.Plug.current_resource(conn)

    unit_ids = Enum.map(params["data"], fn unit -> Map.get(unit, "id") end)

    existing_units =
      QueryManager.query(project: project, arke: arke.id)
      |> QueryFilters.apply_query_filters(permission.filter)
      |> QueryFilters.apply_member_child_only(member, Map.get(permission, :child_only, false))
      |> QueryManager.where(id__in: unit_ids)
      |> QueryManager.all()

    QueryManager.update_bulk(project, arke, existing_units, params["data"])
    |> case do
      {:ok, updated_count, errors} ->
        error_units =
          Enum.map(errors, fn {unit, unit_errors} ->
            Map.put(
              StructManager.encode(unit,
                load_links: load_links,
                load_values: load_values,
                type: :json
              ),
              "errors",
              unit_errors
            )
          end)

        ResponseManager.send_resp(conn, 200, %{
          content: %{
            success_count: updated_count,
            error_count: length(error_units),
            error_units: error_units
          }
        })

      {:error, error} ->
        ResponseManager.send_resp(conn, 400, nil, error)
    end
  end
end
