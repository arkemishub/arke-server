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

defmodule ArkeServer.StructController do
  @moduledoc """
              Documentation for`ArkeServer.StructController
             """ && false
  use ArkeServer, :controller
  alias Arke.{StructManager}
  alias Arke.Boundary.ArkeManager
  alias ArkeServer.ResponseManager

  alias ArkeServer.Openapi.Responses

  alias OpenApiSpex.{Operation, Reference}

  # ------- start OPENAPI spec -------

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def get_unit_struct_operation() do
    %Operation{
      tags: ["Struct"],
      summary: "Get unit struct",
      description:
        "Get all the parameter and their types associated to the given element. Useful to create/update",
      operationId: "ArkeServer.TopologyController.get_unit_struct",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
        %Reference{"$ref": "#/components/parameters/unit_id"},
        %Reference{"$ref": "#/components/parameters/arke-project-key"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([201, 204])
    }
  end

  def get_arke_struct_operation() do
    %Operation{
      tags: ["Struct"],
      summary: "Get arke struct",
      description:
        "Get all the parameter and their types associated to the given element. Useful to create/update",
      operationId: "ArkeServer.TopologyController.get_arke_struct",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
        %Reference{"$ref": "#/components/parameters/arke-project-key"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([201, 204])
    }
  end

  # ------- end OPENAPI spec -------

  @doc """
       Get a struct of a unit
       """ && false
  def get_unit_struct(conn, %{"arke_id" => arke_id, "arke_unit_id" => _id}) do
    project = conn.assigns[:arke_project]
    arke = ArkeManager.get(String.to_existing_atom(arke_id), project)
    arke = Arke.Core.Unit.update(arke, runtime_data: %{conn: conn})
    ResponseManager.send_resp(conn, 200, %{
      content: StructManager.get_struct(arke, conn.assigns[:unit], conn.query_params)
    })
  end

  @doc """
       Get a struct of an Arke
       """ && false
  def get_arke_struct(conn, %{"arke_id" => id}) do
    project = conn.assigns[:arke_project]

    struct =
      ArkeManager.get(String.to_atom(id), project)
      |> Arke.Core.Unit.update(runtime_data: %{conn: conn})
      |> StructManager.get_struct(conn.query_params)

    ResponseManager.send_resp(conn, 200, %{content: struct})
  end
end
