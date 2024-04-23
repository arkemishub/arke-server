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

defmodule ArkeServer.Openapi.UnitControllerSpec do
  @moduledoc """
  Definition of the ApiSpec for `ArkeServer.UnitController`.
  """

  alias ArkeServer.Openapi.Responses
  alias OpenApiSpex.{Operation, Reference}


  def search_operation() do
    %Operation{
      tags: ["Unit"],
      summary: "Global search",
      description: "Search between all the units",
      operationId: "ArkeServer.ArkeController.search",
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

end
