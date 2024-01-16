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
  alias ArkeServer.ResponseManager
  alias ArkeAuth.Core.{User, Auth, Otp}
  alias Arke.Boundary.ArkeManager
  alias ArkeAuth.Boundary.OtpManager
  alias Arke.{QueryManager, LinkManager}
  alias Arke.Utils.ErrorGenerator, as: Error
  alias Arke.DatetimeHandler

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

  # ------- end OPENAPI spec -------

  defp data_as_klist(data) do
    Enum.map(data, fn {key, value} -> {String.to_existing_atom(key), value} end)
  end

  defp get_review_email() do
    case System.get_env("APP_REVIEW_EMAIL") do
      nil -> []
      data -> String.split(data, ",")
    end
  end

  @doc """
  Signin a user
  """
  def signup(%{body_params: params} = conn, %{"arke_id" => arke_id}) do
    project = get_project(conn.assigns[:arke_project])
    auth_mode = System.get_env("AUTH_MODE", "default")
    arke = ArkeManager.get(arke_id, project)

    with %Arke.Core.Unit{} = unit <- Arke.Core.Unit.load(arke, data_as_klist(params), :create),
         {:ok, unit} <- Arke.Validator.validate(unit, :create, project),
         do: handle_signup_mode(conn, arke, params, project, auth_mode),
         #         do: %{},
         else: ({:error, errors} -> ResponseManager.send_resp(conn, 400, errors))
  end

  defp handle_signup_mode(
         conn,
         arke,
         params,
         project,
         "default"
       ),
       do: handle_signup(conn, arke, params, project)

  defp handle_signup_mode(conn, _, _, project, "default"),
    do: ResponseManager.send_resp(conn, 400, "Username and Password required")

  defp handle_signup_mode(
         conn,
         arke,
         %{
           "otp" => otp,
           "arke_system_user" => %{"username" => username},
           "email" => email,
           "first_name" => first_name,
           "last_name" => last_name
         } = params,
         project,
         "otp_mail"
       )
       when is_nil(otp) do
    case Otp.generate(project, username, "signup") do
      {:ok, otp} ->
        full_name = "#{first_name} #{last_name}"

        res_mail =
          ArkeServer.EmailManager.send_email(
            to: {full_name, email},
            template_uuid: "2bac0781-93a9-42f7-8c28-536af16e2e71",
            template_variables: %{name: full_name, otp: otp.data.code, expire: "5 minuti"}
          )

        ResponseManager.send_resp(conn, 200, %{content: "OTP send successfully"})

      {:error, errors} ->
        ResponseManager.send_resp(conn, 401, nil, errors)
    end
  end

  defp handle_signup_mode(
         conn,
         arke,
         %{"otp" => otp, "arke_system_user" => %{"username" => username}} = params,
         project,
         "otp_mail"
       ) do
    QueryManager.get_by(
      project: project,
      arke: "otp",
      id: Otp.parse_otp_id("signup", username),
      action: "signup"
    )
    |> case do
      nil ->
        ResponseManager.send_resp(conn, 401, nil, "Unauthorized")

      otp_unit ->
        case otp_unit.data.code == otp do
          true ->
            case NaiveDateTime.compare(otp_unit.data.expiry_datetime, NaiveDateTime.utc_now()) do
              :lt ->
                ResponseManager.send_resp(conn, 410, nil, "Gone")

              :gt ->
                QueryManager.delete(project, otp_unit)
                handle_signup(conn, arke, params, project)
            end

          false ->
            ResponseManager.send_resp(conn, 401, nil, nil)
        end
    end
  end

  defp handle_signup_mode(conn, _, _, project, "otp_mail"),
    do: ResponseManager.send_resp(conn, 400, "Username, Password and OTP required")

  defp handle_signup_mode(conn, _, _, project, _),
    do: ResponseManager.send_resp(conn, 400, "Signup method not active")

  defp handle_signup(
         conn,
         arke,
         %{"arke_system_user" => %{"username" => username, "password" => password}} = params,
         project
       ) do
    {_, params} = Map.pop(params, "otp")

    QueryManager.create(project, arke, data_as_klist(params))
    |> case do
      {:ok, member} ->
        Auth.validate_credentials(username, password, project)
        |> case do
          {:ok, member, access_token, refresh_token} ->
            content =
              Map.merge(Arke.StructManager.encode(member, type: :json), %{
                access_token: access_token,
                refresh_token: refresh_token
              })

            ResponseManager.send_resp(conn, 200, %{content: content})

          {:error, error} ->
            ResponseManager.send_resp(conn, 401, nil, error)
        end

      {:error, error} ->
        ResponseManager.send_resp(conn, 400, nil, error)
    end

    #    Auth.validate_credentials(username, password, project)
    #    |> case do
    #         {:ok, member, access_token, refresh_token} ->
    #           content =
    #             Map.merge(Arke.StructManager.encode(member, type: :json), %{
    #               access_token: access_token,
    #               refresh_token: refresh_token
    #             })
    #
    #           ResponseManager.send_resp(conn, 200, %{content: content})
    #
    #         {:error, error} ->
    #           ResponseManager.send_resp(conn, 401, nil, error)
    #       end
  end

  #  @doc """
  #  Register a new user
  #  """
  #  def signup(conn, %{"username" => _, "password" => _} = params) do
  #    project = get_project(conn.assigns[:arke_project])
  #    user_model = ArkeManager.get(:user, :arke_system)
  #
  #    QueryManager.create(project, user_model, data_as_klist(params))
  #    |> case do
  #      {:ok, user} ->
  #        ResponseManager.send_resp(conn, 201, %{
  #          content: Arke.StructManager.encode(user, type: :json)
  #        })
  #
  #      {:error, error} ->
  #        ResponseManager.send_resp(conn, 400, nil, error)
  #    end
  #  end

  @doc """
  Signin a user
  """
  def signin(conn, %{"username" => username, "password" => password} = params) do
    project = get_project(conn.assigns[:arke_project])
    auth_mode = System.get_env("AUTH_MODE", "default")

    Auth.validate_credentials(username, password, project)
    |> case do
      {:ok, member, access_token, refresh_token} ->
        case member.arke_id do
          :super_admin ->
            handle_signin(conn, username, password, project)

          _ ->
            handle_signin_mode(conn, params, project, auth_mode)
        end

      {:error, messages} ->
        ResponseManager.send_resp(conn, 401, messages)
    end
  end

  defp handle_signin_mode(
         conn,
         %{"username" => username, "password" => password},
         project,
         "default"
       ),
       do: handle_signin(conn, username, password, project)

  defp handle_signin_mode(conn, _, project, "default"),
    do: ResponseManager.send_resp(conn, 400, "Username and Password required")

  defp handle_signin_mode(
         conn,
         %{"username" => username, "password" => password, "otp" => otp},
         project,
         "otp_mail"
       )
       when is_nil(otp) do
    Auth.validate_credentials(username, password, project)
    |> case do
      {:ok, member, access_token, refresh_token} ->
        full_name = "#{member.data.first_name} #{member.data.last_name}"
        email = member.data.email

        data = %{
          arke_id: member.arke_id,
          id: member.id,
          arke_system_user: member.data.arke_system_user,
          email: member.data.email,
          inactive: Map.get(member.data, :inactive, false)
        }

        reviewer = get_review_email()

        if username in reviewer do
          send_email(full_name, email, "1234")
          ResponseManager.send_resp(conn, 200, data, "OTP send successfully")
        else
          case Otp.generate(project, member.id, "signin") do
            {:ok, otp} ->
              send_email(full_name, email, otp.data.code)
              # TODO implement only `opt` in `StructManager.encode`

              ResponseManager.send_resp(conn, 200, data, "OTP send successfully")

            {:error, errors} ->
              ResponseManager.send_resp(conn, 401, nil, errors)
          end
        end

      {:error, error} ->
        ResponseManager.send_resp(conn, 401, nil, error)
    end
  end

  defp send_email(name, email, code) do
    ArkeServer.EmailManager.send_email(
      to: {name, email},
      template_uuid: "cd331f05-6fb7-460d-9639-d6f14d4ce02f",
      template_variables: %{name: name, otp: code, expire: "5 minuti"}
    )
  end

  defp handle_signin_mode(
         conn,
         %{"username" => username, "password" => password, "otp" => otp},
         project,
         "otp_mail"
       ) do
    Auth.validate_credentials(username, password, project)
    |> case do
      {:ok, member, access_token, refresh_token} ->
        reviewer = get_review_email()

        if username in reviewer do
          if otp == "1234" do
            handle_signin(conn, username, password, project)
          else
            ResponseManager.send_resp(conn, 401, nil, "Unauthorized")
          end
        else
          QueryManager.get_by(
            project: project,
            arke: "otp",
            id: Otp.parse_otp_id("signin", member.id),
            action: "signin"
          )
          |> case do
            nil ->
              ResponseManager.send_resp(conn, 401, nil, "Unauthorized")

            otp_unit ->
              case otp_unit.data.code == otp do
                true ->
                  case NaiveDateTime.compare(
                         otp_unit.data.expiry_datetime,
                         NaiveDateTime.utc_now()
                       ) do
                    :lt ->
                      ResponseManager.send_resp(conn, 410, nil, "Gone")

                    :gt ->
                      QueryManager.delete(project, otp_unit)
                      handle_signin(conn, username, password, project)
                  end

                false ->
                  ResponseManager.send_resp(conn, 401, nil, nil)
              end
          end
        end

      {:error, error} ->
        ResponseManager.send_resp(conn, 401, nil, error)
    end
  end

  defp handle_signin_mode(conn, _, project, "otp_mail"),
    do: ResponseManager.send_resp(conn, 400, "Username, Password and OTP required")

  defp handle_signin_mode(conn, _, project, _),
    do: ResponseManager.send_resp(conn, 400, "Auth method not active")

  defp handle_signin(conn, username, password, project) do
    Auth.validate_credentials(username, password, project)
    |> case do
      {:ok, member, access_token, refresh_token} ->
        content =
          Map.merge(Arke.StructManager.encode(member, type: :json), %{
            access_token: access_token,
            refresh_token: refresh_token
          })

        ResponseManager.send_resp(conn, 200, %{content: content})

      {:error, error} ->
        ResponseManager.send_resp(conn, 401, nil, error)
    end
  end

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
    project = get_project(conn.assigns[:arke_project])
    auth_mode = System.get_env("AUTH_MODE", "default")
    member = ArkeAuth.Guardian.Plug.current_resource(conn)

    case member.arke_id do
      :super_admin ->
        handle_change_password(conn, member, old_pwd, new_pwd)

      _ ->
        handle_change_password_mode(conn, params, member, "default")
    end
  end

  defp handle_change_password_mode(
         conn,
         %{"old_password" => old_pwd, "password" => new_pwd},
         member,
         "default"
       ),
       do: handle_change_password(conn, member, old_pwd, new_pwd)

  defp handle_change_password_mode(conn, _, _, "default"),
    do: ResponseManager.send_resp(conn, 400, "Old password and New password required")

  defp handle_change_password_mode(
         conn,
         %{"old_password" => old_pwd, "password" => new_pwd, "otp" => otp},
         %{metadata: %{project: project}} = member,
         "otp_mail"
       )
       when is_nil(otp) do
    otp_arke = ArkeManager.get(:otp, :arke_system)

    OtpManager.get(member.id, project)
    |> case do
      nil -> :ok
      otp -> OtpManager.remove(otp)
    end

    otp =
      Arke.Core.Unit.new(
        member.id,
        %{
          code: "1234",
          action: "change_password",
          expiry_datetime: NaiveDateTime.utc_now() |> NaiveDateTime.add(300, :second)
        },
        otp_arke.id,
        nil,
        %{},
        DateTime.utc_now(),
        DateTime.utc_now(),
        ArkeAuth.Core.Otp,
        %{}
      )

    OtpManager.create(otp, project)
    ResponseManager.send_resp(conn, 200, %{content: "OTP send successfully"})
  end

  defp handle_change_password_mode(
         conn,
         %{"old_password" => old_pwd, "password" => new_pwd, "otp" => otp},
         %{metadata: %{project: project}} = member,
         "otp_mail"
       ) do
    OtpManager.get(member.id, project)
    |> case do
      nil ->
        ResponseManager.send_resp(conn, 401, nil, "Unauthorized")

      otp_unit ->
        case otp_unit.data.code == otp do
          true ->
            case NaiveDateTime.compare(otp_unit.data.expiry_datetime, NaiveDateTime.utc_now()) do
              :lt ->
                ResponseManager.send_resp(conn, 410, nil, "Gone")

              :gt ->
                OtpManager.remove(otp_unit)
                handle_change_password(conn, member, old_pwd, new_pwd)
            end

          false ->
            ResponseManager.send_resp(conn, 401, nil, nil)
        end
    end
  end

  defp handle_change_password_mode(conn, _, _, "otp_mail"),
    do:
      ResponseManager.send_resp(conn, 400, "Old password, New password required and OTP required")

  defp handle_change_password_mode(conn, _, _, _),
    do: ResponseManager.send_resp(conn, 400, "Auth method not active")

  defp handle_change_password(conn, member, old_pwd, new_pwd) do
    user =
      QueryManager.get_by(project: :arke_system, arke_id: :user, id: member.data.arke_system_user)

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

  def recover_password(conn, %{"email" => email} = params) do
    project = get_project(conn.assigns[:arke_project])
    auth_mode = System.get_env("AUTH_MODE", "default")

    case QueryManager.get_by(project: project, group_id: :arke_auth_member, email: email) do
      nil ->
        ResponseManager.send_resp(conn, 404, "member not found with given email")

      member ->
        case member.arke_id do
          :super_admin ->
            handle_recover_password(conn, member, params)

          _ ->
            handle_recover_password_mode(conn, params, member, auth_mode)
        end
    end
  end

  defp handle_recover_password_mode(
         conn,
         %{"email" => email},
         member,
         "default"
       ),
       do: handle_recover_password_mode(conn, member, email, "default")

  defp handle_recover_password_mode(conn, _, _, "default"),
    do: ResponseManager.send_resp(conn, 400, "Email required")

  defp handle_recover_password_mode(
         conn,
         %{"email" => email, "otp" => otp},
         %{metadata: %{project: project}} = member,
         "otp_mail"
       )
       when is_nil(otp) do
    otp_arke = ArkeManager.get(:otp, :arke_system)

    case Otp.generate(project, member.id, "reset_password") do
      {:ok, otp} ->
        full_name = "#{member.data.first_name} #{member.data.last_name}"

        res_mail =
          ArkeServer.EmailManager.send_email(
            to: {full_name, member.data.email},
            template_uuid: "f8b2c3e4-7b3e-4ab3-b626-8ddd11cb8a6c",
            template_variables: %{
              name: full_name,
              otp: otp.data.code,
              expire: "5 minuti",
              user_email: member.data.email
            }
          )

        ResponseManager.send_resp(conn, 200, %{content: "OTP send successfully"})

      {:error, errors} ->
        ResponseManager.send_resp(conn, 401, nil, errors)
    end
  end

  defp handle_recover_password_mode(conn, _, _, "otp_mail"),
    do: ResponseManager.send_resp(conn, 400, "Email required and OTP required")

  defp handle_recover_password_mode(conn, _, _, _),
    do: ResponseManager.send_resp(conn, 400, "Auth method not active")

  defp handle_recover_password(conn, email, "default") do
    case QueryManager.get_by(email: email, project: :arke_system) do
      nil ->
        {:error, msg} = Error.create(:auth, "no user found with the given email")
        ResponseManager.send_resp(conn, 200, nil)

      user ->
        old_token_list =
          QueryManager.filter_by(
            project: :arke_system,
            arke_id: :reset_password_token,
            user_id: user.id
          )

        Enum.each(old_token_list, fn unit -> QueryManager.delete(:arke_system, unit) end)
        token_model = ArkeManager.get(:reset_password_token, :arke_system)

        case QueryManager.create(:arke_system, token_model, %{user_id: to_string(user.id)}) do
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

              {:error, {_code, _error}} ->
                {:error, msg} = Error.create(:auth, "service mail error")
                ResponseManager.send_resp(conn, 400, nil, msg)
            end
        end
    end
  end

  def recover_password(conn, _), do: ResponseManager.send_resp(conn, 400, nil)

  def reset_password(conn, params) do
    project = get_project(conn.assigns[:arke_project])
    auth_mode = System.get_env("AUTH_MODE", "default")

    email = Map.get(params, "email", nil)

    case QueryManager.get_by(project: project, group_id: :arke_auth_member, email: email) do
      nil ->
        handle_reset_password_mode(conn, params, nil, auth_mode)

      member ->
        case member.arke_id do
          :super_admin ->
            handle_reset_password_mode(conn, params, member, auth_mode)

          _ ->
            handle_reset_password_mode(conn, params, member, auth_mode)
        end
    end
  end

  defp handle_reset_password_mode(
         conn,
         %{"new_password" => new_password, "token" => token} = params,
         member,
         "default"
       ) do
    with %Arke.Core.Unit{} = token_unit <-
           QueryManager.get_by(
             arke_id: :reset_password_token,
             token: token,
             project: :arke_system
           ),
         {:ok, token_unit} <- check_token_expiration(token_unit),
         %Arke.Core.Unit{} = user <-
           QueryManager.get_by(id: token_unit.data.user_id, project: :arke_system),
         {:ok, _updated_user} <- User.update_password(user, new_password) do
      QueryManager.delete(:arke_system, token_unit)
      ResponseManager.send_resp(conn, 200, nil)
    else
      nil ->
        ResponseManager.send_resp(conn, 400, nil, %{
          context: :auth,
          message: "invalid token"
        })

      {:error, msg} ->
        ResponseManager.send_resp(conn, 400, nil, msg)
    end
  end

  defp handle_reset_password_mode(
         conn,
         %{"new_password" => new_password, "otp" => otp},
         %{metadata: %{project: project}} = member,
         "otp_mail"
       ) do
    QueryManager.get_by(
      project: project,
      arke: "otp",
      id: Otp.parse_otp_id("reset_password", member.id),
      action: "reset_password"
    )
    |> case do
      nil ->
        ResponseManager.send_resp(conn, 401, nil, "Unauthorized")

      otp_unit ->
        case otp_unit.data.code == otp do
          true ->
            case NaiveDateTime.compare(otp_unit.data.expiry_datetime, NaiveDateTime.utc_now()) do
              :lt ->
                ResponseManager.send_resp(conn, 410, nil, "Gone")

              :gt ->
                QueryManager.delete(project, otp_unit)

                user =
                  QueryManager.get_by(
                    id: member.data.arke_system_user,
                    arke_id: :user,
                    project: :arke_system
                  )

                User.update_password(user, new_password)
                ResponseManager.send_resp(conn, 200, nil, nil)
            end

          false ->
            ResponseManager.send_resp(conn, 401, nil, nil)
        end
    end
  end

  def reset_password(conn, _), do: ResponseManager.send_resp(conn, 400, nil)

  defp get_project(project) when is_nil(project), do: :arke_system
  defp get_project(project), do: project

  defp check_token_expiration(%Arke.Core.Unit{} = token) do
    with {:ok, value} <- DatetimeHandler.parse_datetime(token.data.expiration),
         true <- DatetimeHandler.after?(value, DatetimeHandler.now(:datetime)) do
      {:ok, token}
    else
      _ -> Error.create(:auth, "expired token")
    end
  end

  defp check_token_expiration(_token), do: Error.create(:auth, "invalid token")
end
