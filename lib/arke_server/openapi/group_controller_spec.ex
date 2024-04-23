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

defmodule ArkeServer.Openapi.GroupControllerSpec do
  @moduledoc """
  Definition of the ApiSpec for `ArkeServer.GroupController`.
  """

  alias ArkeServer.Openapi.Responses
  alias OpenApiSpex.{Operation, Reference}

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
end
