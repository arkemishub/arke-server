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

defmodule ArkeServer.Openapi.AuthControllerSpec do
  @moduledoc """
  Definition of the ApiSpec for `ArkeServer.AuthController`.
  """

  alias ArkeServer.Openapi.Responses
  alias OpenApiSpex.{Operation, Reference}

  def signin_operation() do
    %Operation{
      tags: ["Auth"],
      summary: "Login",
      description: "Provide credentials to login to the app",
      operationId: "ArkeServer.AuthController.signin",
      requestBody:
        OpenApiSpex.Operation.request_body(
          "Parameters to login",
          "application/json",
          ArkeServer.Schemas.UserParams,
          required: true
        ),
      responses: Responses.get_responses([201, 204])
    }
  end

  def signup_operation() do
    %Operation{
      tags: ["Auth"],
      summary: "Signup",
      description: "Create a new user for the app",
      operationId: "ArkeServer.AuthController.signup",
      requestBody:
        OpenApiSpex.Operation.request_body(
          "Parameters for the signup",
          "application/json",
          ArkeServer.Schemas.UserExample,
          required: true
        ),
      responses: Responses.get_responses([201, 204])
    }
  end

  def refresh_operation() do
    %Operation{
      tags: ["Auth"],
      summary: "Refresh token",
      description:
        "Exchange the refresh token with a new couple access_token and refresh_token. Send the refresh token in the `authorization` header",
      operationId: "ArkeServer.AuthController.refresh",
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([201, 204])
    }
  end

  def verify_operation() do
    %Operation{
      tags: ["Auth"],
      summary: "Verify token",
      description: "Check if the current access_token is still valid otherwise try to refresh it",
      operationId: "ArkeServer.AuthController.verify",
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([201, 204])
    }
  end

  def change_password_operation() do
    %Operation{
      tags: ["Auth"],
      summary: "Change user password",
      description: "Changhe user pasword",
      operationId: "ArkeServer.AuthController.change_password",
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([200, 400])
    }
  end

  def recover_password_operation() do
    %Operation{
      tags: ["Auth"],
      summary: "Send email to reset passsword",
      description: "Send an email containing a link to reset the password",
      operationId: "ArkeServer.AuthController.recover_password",
      security: [],
      responses: Responses.get_responses([200, 400])
    }
  end

  def reset_password_operation() do
    %Operation{
      tags: ["Auth"],
      summary: "Reset the user password",
      description: "Reset the user password",
      operationId: "ArkeServer.AuthController.reset_password",
      security: [],
      responses: Responses.get_responses([200, 400])
    }
  end

end
