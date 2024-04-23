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

defmodule ArkeServer.Openapi.ArkeControllerSpec do
  @moduledoc """
             Definition of the ApiSpec for `ArkeServer.ArkeController`.
             """

  alias ArkeServer.Openapi.Responses
  alias OpenApiSpex.{Operation, Reference}


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
  def call_arke_function_operation() do
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
  def call_unit_function_operation() do
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

end
