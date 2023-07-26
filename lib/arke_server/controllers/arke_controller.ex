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

defmodule ArkeServer.ArkeController do
  @moduledoc """
             Documentation for  `ArkeServer.ArkeController`.
             """ && false

  use ArkeServer, :controller
  alias Arke.{QueryManager, LinkManager, StructManager}
  alias Arke.Boundary.ArkeManager
  alias UnitSerializer
  alias ArkeServer.ResponseManager
  alias ArkeServer.Utils.{QueryFilters, QueryProcessor}

  alias ArkeServer.Openapi.Responses

  alias OpenApiSpex.{Operation, Reference}

  # ------- start OPENAPI spec -------
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def get_unit_operation() do
    %Operation{
      tags: ["Unit"],
      summary: "Get unit",
      description: "Get all the units of an Arke",
      operationId: "ArkeServer.ArkeController.get_unit",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
        %Reference{"$ref": "#/components/parameters/unit_id"},
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

  def create_operation() do
    %Operation{
      tags: ["Unit"],
      summary: "Create Unit",
      description: "Create a new unit for the given Arke",
      operationId: "ArkeServer.ArkeController.create",
      parameters: [%Reference{"$ref": "#/components/parameters/arke-project-key"}],
      requestBody:
        OpenApiSpex.Operation.request_body(
          "Parameters to create a unit",
          "application/json",
          ArkeServer.Schemas.CreateUnitExample,
          required: true
        ),
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([200, 204])
    }
  end

  def update_operation() do
    %Operation{
      tags: ["Unit"],
      summary: "Login",
      description: "Provide credentials to login to the app",
      operationId: "ArkeServer.ArkeController.update",
      parameters: [%Reference{"$ref": "#/components/parameters/arke-project-key"}],
      requestBody:
        OpenApiSpex.Operation.request_body(
          "Parameters to login",
          "application/json",
          ArkeServer.Schemas.UserParams,
          required: true
        ),
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([201, 204])
    }
  end

  def delete_operation() do
    %Operation{
      tags: ["Unit"],
      summary: "Delete Unit",
      description: "Delete a specific Unit",
      operationId: "ArkeServer.ArkeController.delete",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
        %Reference{"$ref": "#/components/parameters/unit_id"},
        %Reference{"$ref": "#/components/parameters/arke-project-key"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([200, 201])
    }
  end

  def get_all_unit_operation() do
    %Operation{
      tags: ["Unit"],
      summary: "Get all",
      description: "Get all the unit for the given Arke",
      operationId: "ArkeServer.ArkeController.get_all_unit",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
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

  def get_groups_operation() do
    %Operation{
      tags: ["Group"],
      summary: "Get arke in group",
      description: "Get all available groups",
      operationId: "ArkeServer.ArkeController.get_groups",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
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

  # ------- end OPENAPI spec -------

  def data_as_klist(data) do
    Enum.map(data, fn {key, value} -> {String.to_existing_atom(key), value} end)
  end

  ## Once the project header has been set to mandatory retrieve it as follows:
  #  project = conn.assigns[:arke_project]

  @doc """
       It returns a unit
       """ && false
  def get_unit(conn, %{"unit_id" => _unit_id}) do
    # TODO handle query parameter with plugs
    load_links = Map.get(conn.query_params, "load_links", "false") == "true"
    load_values = Map.get(conn.query_params, "load_values", "false") == "true"

    ResponseManager.send_resp(conn, 200, %{
      content:
        StructManager.encode(conn.assigns[:unit],
          load_links: load_links,
          load_values: load_values,
          type: :json
        )
    })
  end

  @doc """
       Create a new unit
       """ && false
  def create(%Plug.Conn{body_params: params} = conn, %{"arke_id" => id}) do
    # all arkes struct and gen server are on :arke_system so it won't be changed to project
    project = conn.assigns[:arke_project]
    arke = ArkeManager.get(String.to_atom(id), project)

    # TODO handle query parameter with plugs
    load_links = Map.get(conn.query_params, "load_links", "false") == "true"
    load_values = Map.get(conn.query_params, "load_values", "false") == "true"

    QueryManager.create(project, arke, data_as_klist(params))
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

  # delete
  @doc """
       Delete a unit
       """ && false
  def delete(conn, %{"unit_id" => _unit_id, "arke_id" => _arke_id}) do
    project = conn.assigns[:arke_project]

    QueryManager.delete(project, conn.assigns[:unit])
    |> case do
      {:ok, nil} -> ResponseManager.send_resp(conn, 204)
      {:error, error} -> ResponseManager.send_resp(conn, 400, nil, error)
    end
  end

  @doc """
       Get units
       """ && false
  def get_all_unit(conn, %{"arke_id" => id}) do
    project = conn.assigns[:arke_project]

    # TODO handle query parameter with plugs
    load_links = Map.get(conn.query_params, "load_links", "false") == "true"
    load_values = Map.get(conn.query_params, "load_values", "false") == "true"

    {count, units} =
      QueryManager.query(project: project, arke: id)
      |> QueryFilters.apply_query_filters(Map.get(conn.assigns, :filter))
      |> QueryProcessor.process_query(conn.query_params)

    ResponseManager.send_resp(conn, 200, %{
      count: count,
      items:
        StructManager.encode(units, load_links: load_links, load_values: load_values, type: :json)
    })
  end

  @doc """
       Get Arke groups
       """ && false
  def get_groups(conn, %{"arke_id" => id}) do
    project = conn.assigns[:arke_project]
    arke = ArkeManager.get(id, project)

    {count, units} =
      QueryManager.query(project: project, arke: :group)
      |> QueryManager.link(arke, direction: :parent, type: "group")
      |> QueryFilters.apply_query_filters(Map.get(conn.assigns, :filter))
      |> QueryProcessor.process_query(conn.query_params)

    ResponseManager.send_resp(conn, 200, %{
      count: count,
      items: StructManager.encode(units, type: :json)
    })
  end
end
