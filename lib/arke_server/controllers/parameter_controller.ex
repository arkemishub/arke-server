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

defmodule ArkeServer.ParameterController do
  use ArkeServer, :controller
  alias Arke.Boundary.ParameterManager
  alias ArkeServer.ResponseManager
  alias Arke.StructManager

  @doc """
       Get parameter value
       """ && false
  def get_parameter_value(conn, %{"parameter" => parameter_id}) do
    project = conn.assigns[:arke_project]
    unit = conn.assigns[:unit]

    # TODO handle get parameter with plug
    parameter = ParameterManager.get(parameter_id, project)

    offset = Map.get(conn.query_params, "offset", 0)
    limit = Map.get(conn.query_params, "limit", 100)
    order = Map.get(conn.query_params, "order", [])

    # TODO handle query parameters with plugs
    load_links = Map.get(conn.query_params, "load_links", "false") == "true"

    {count, units} = {0, []}
    # QueryManager.query(project: project)
    # |> QueryManager.link(unit, depth)
    # |> QueryFilters.apply_query_filters(Map.get(conn.assigns, :filter))
    # |> QueryOrder.apply_order(order)
    # |> QueryManager.pagination(offset, limit)

    ResponseManager.send_resp(conn, 200, %{
      count: count,
      items: StructManager.encode(units, type: :json)
    })
  end

  def update_parameter_value(conn, _body),
    do: ResponseManager.send_resp(conn, 200, nil)

  def add_link_parameter_value(conn, _body),
    do: ResponseManager.send_resp(conn, 201, nil)

  def remove_link_parameter_value(conn, _body),
    do: ResponseManager.send_resp(conn, 204)
end
