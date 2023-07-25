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

defmodule ArkeServer.AuthController do
  @moduledoc """
             Documentation for `ArkeServer.AuthController`. Used from the controller and via API not from CLI
             """ && false

  use ArkeServer, :controller
  alias ElixirSense.Plugins.Ecto.Query
  alias ArkeServer.ResponseManager
  alias ArkeAuth.Core.{User, Auth}
  alias Arke.Boundary.ArkeManager
  alias Arke.{QueryManager, LinkManager}
  alias Arke.Utils.ErrorGenerator, as: Error

  alias ArkeServer.Openapi.Responses

  alias OpenApiSpex.{Operation, Reference}

  # ------- start OPENAPI spec -------
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

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

  def create_token() do
    %Operation{
      tags: ["Auth"],
      summary: "Send email to reset passsword",
      description: "Send an email containing a link to reset the password",
      operationId: "ArkeServer.AuthController.create_token",
      security: [],
      responses: Responses.get_responses([200, 400])
    }
  end

  def reset_password() do
    %Operation{
      tags: ["Auth"],
      summary: "Reset the user password",
      description: "Reset the user password",
      operationId: "ArkeServer.AuthController.reset_password",
      security: [],
      responses: Responses.get_responses([200, 400])
    }
  end

  # ------- end OPENAPI spec -------

  defp data_as_klist(data) do
    Enum.map(data, fn {key, value} -> {String.to_existing_atom(key), value} end)
  end

  @doc """
  Register a new user
  """
  def signup(conn, %{"username" => _, "password" => _} = params) do
    project = get_project(conn.assigns[:arke_project])
    user_model = ArkeManager.get(:user, :arke_system)

    QueryManager.create(project, user_model, data_as_klist(params))
    |> case do
      {:ok, user} ->
        ResponseManager.send_resp(conn, 201, %{
          content: Arke.StructManager.encode(user, type: :json)
        })

      {:error, error} ->
        ResponseManager.send_resp(conn, 400, nil, error)
    end
  end

  @doc """
  Signin a user
  """
  def signin(conn, %{"username" => username, "password" => password}) do
    project = get_project(conn.assigns[:arke_project])

    Auth.validate_credentials(username, password, project)
    |> case do
      {:ok, user, access_token, refresh_token} ->
        content =
          Map.merge(Arke.StructManager.encode(user, type: :json), %{
            access_token: access_token,
            refresh_token: refresh_token
          })

        ResponseManager.send_resp(conn, 200, %{content: content})

      {:error, error} ->
        ResponseManager.send_resp(conn, 401, nil, error)
    end
  end

  def signin(conn, _params), do: ResponseManager.send_resp(conn, 404, nil)

  @doc """
  Refresh the JWT tokens. Returns 200 and the tokes if ok
  """
  def refresh(conn, _) do
    user = ArkeAuth.Guardian.Plug.current_resource(conn)
    token = ArkeAuth.Guardian.Plug.current_token(conn)

    Auth.refresh_tokens(user, token)
    |> case do
      {:ok, access_token, refresh_token} ->
        ResponseManager.send_resp(conn, 200, %{
          content: %{access_token: access_token, refresh_token: refresh_token}
        })

      {:error, error} ->
        ResponseManager.send_resp(conn, 400, nil, error)
    end
  end

  @doc """
  Verify if the token is still valid. Returns 200 if true
    - conn => %Plug.Conn{}
  """
  def verify(conn, _) do
    ResponseManager.send_resp(conn, 200, nil)
  end

  @doc """
  Change user password
  """
  def change_password(conn, %{"old_password" => old_pwd, "password" => new_pwd} = params) do
    user = ArkeAuth.Guardian.Plug.current_resource(conn)

    Auth.change_password(user, old_pwd, new_pwd)
    |> case do
      {:ok, user} ->
        ResponseManager.send_resp(conn, 200, %{
          content: Arke.StructManager.encode(user, type: :json)
        })

      {:error, error} ->
        ResponseManager.send_resp(conn, 400, nil, error)
    end
  end

  def change_password(conn, _), do: ResponseManager.send_resp(conn, 400, nil)

  @doc """
  Reset user password
  """
  def create_token(conn, %{"email" => email} = _params) do
    project = get_project(conn.assigns[:arke_project])

    case QueryManager.get_by(email: email, project: :arke_system) do
      nil ->
        {:error, msg} = Error.create(:auth, "no user found with the given email")
        ResponseManager.send_resp(conn, 400, nil, msg)

      user ->
        token_model = ArkeManager.get(:reset_password_token, :arke_system)

        case QueryManager.create(project, token_model, %{user_id: to_string(user.id)}) do
          {:error, error} ->
            ResponseManager.send_resp(conn, 400, nil, error)

          {:ok, unit} ->
            url_token = unit.data.token
            endpoint = "#{System.get_env("RESET_PASSWORD_ENDPOINT", "")}/#{url_token}"

            case ArkeServer.EmailManager.send_email(
                   to: Map.fetch!(user.data, :email),
                   subject: "Reset Password",
                   template_name: "reset_password",
                   text: endpoint,
                   custom_vars: %{"reset-endpoint": endpoint}
                 ) do
              {:ok, _} ->
                ResponseManager.send_resp(conn, 200, nil)

              {:error, {_code, error}} ->
                ResponseManager.send_resp(conn, 400, nil, %{
                  context: :auth,
                  message: Map.get(error, "message")
                })
            end
        end
    end
  end

  def create_token(conn, _), do: ResponseManager.send_resp(conn, 400, nil)

  def reset_password(conn, %{"new_password" => new_password, "token" => token} = params) do
    # TODO check expiration
    with %Arke.Core.Unit{} = token_unit <-
           QueryManager.get_by(
             arke_id: :reset_password_token,
             token: token,
             project: :arke_system
           ),
         %Arke.Core.Unit{} = user <-
           QueryManager.get_by(id: token_unit.data.user_id, project: :arke_system),
         {:ok, updated_user} <- User.update_password(user, new_password),
         do: ResponseManager.send_resp(conn, 200, nil),
         else:
           (_ ->
              ResponseManager.send_resp(conn, 400, nil, %{
                context: :auth,
                message: "invalid token"
              }))
  end

  def reset_password(conn, _), do: ResponseManager.send_resp(conn, 400, nil)

  defp get_project(project) when is_nil(project), do: :arke_system
  defp get_project(project), do: project
end
