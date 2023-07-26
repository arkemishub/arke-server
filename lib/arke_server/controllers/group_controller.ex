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
             """ && false
  use ArkeServer, :controller
  alias Arke.{QueryManager, LinkManager, StructManager}
  alias Arke.Core.Unit
  alias Arke.Boundary.{ArkeManager, GroupManager}
  alias ArkeServer.ResponseManager
  alias ArkeServer.Utils.{QueryFilters, QueryProcessor}

  alias ArkeServer.Openapi.Responses

  alias OpenApiSpex.{Operation, Reference}

  # ------- start OPENAPI spec -------
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def struct_operation() do
    %Operation{
      tags: ["Group"],
      summary: "Group struct",
      description: "Get the struct for the given group",
      operationId: "ArkeServer.ArkeController.struct",
      parameters: [
        %Reference{"$ref": "#/components/parameters/group_id"},
        %Reference{"$ref": "#/components/parameters/arke-project-key"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([201, 204])
    }
  end

  def get_arke_operation() do
    %Operation{
      tags: ["Group"],
      summary: "Arke list",
      description: "Get all theArke in the given group",
      operationId: "ArkeServer.ArkeController.get_arke",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke-project-key"},
        %Reference{"$ref": "#/components/parameters/limit"},
        %Reference{"$ref": "#/components/parameters/offset"},
        %Reference{"$ref": "#/components/parameters/order"},
        %Reference{"$ref": "#/components/parameters/filter"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([201, 204])
    }
  end

  def get_unit_operation() do
    %Operation{
      tags: ["Group"],
      summary: "Unit list",
      description: "Get all the units of all the Arke in the given group",
      operationId: "ArkeServer.ArkeController.get_unit",
      parameters: [
        %Reference{"$ref": "#/components/parameters/group_id"},
        %Reference{"$ref": "#/components/parameters/arke-project-key"},
        %Reference{"$ref": "#/components/parameters/limit"},
        %Reference{"$ref": "#/components/parameters/offset"},
        %Reference{"$ref": "#/components/parameters/order"},
        %Reference{"$ref": "#/components/parameters/filter"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([201, 204])
    }
  end

  def unit_detail_operation() do
    %Operation{
      tags: ["Group"],
      summary: "Unit detail",
      description: "Get the detail of the given unit in a given group",
      operationId: "ArkeServer.ArkeController.unit_detail",
      parameters: [
        %Reference{"$ref": "#/components/parameters/group_id"},
        %Reference{"$ref": "#/components/parameters/unit_id"},
        %Reference{"$ref": "#/components/parameters/arke-project-key"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([201, 204])
    }
  end

  # ------- end OPENAPI spec -------

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

    {count, units} =
      QueryManager.query(project: project)
      |> QueryManager.filter(:group_id, :eq, group_id, false)
      |> QueryFilters.apply_query_filters(Map.get(conn.assigns, :filter))
      |> QueryProcessor.process_query(conn.query_params)

    ResponseManager.send_resp(conn, 200, %{
      count: count,
      items: StructManager.encode(units, type: :json)
    })
  end

  # get the detail of the unit in the given group id based on the unit_id
  def unit_detail(conn, %{"group_id" => group_id, "unit_id" => unit_id}) do
    project = conn.assigns[:arke_project]
    unit = QueryManager.get_by(project: project, group_id: group_id, id: unit_id)
    ResponseManager.send_resp(conn, 200, %{content: StructManager.encode(unit, type: :json)})
  end
end
