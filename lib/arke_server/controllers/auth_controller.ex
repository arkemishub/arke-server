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
             """

  use ArkeServer, :controller

  # Openapi request definition
  use ArkeServer.Openapi.Spec, module: ArkeServer.Openapi.AuthControllerSpec

  alias ArkeServer.ResponseManager
  alias ArkeAuth.Core.{User, Auth, Otp}
  alias Arke.Boundary.ArkeManager
  alias ArkeAuth.Boundary.OtpManager
  alias Arke.{QueryManager, LinkManager}
  alias Arke.Utils.ErrorGenerator, as: Error
  alias Arke.Utils.DatetimeHandler

  alias ArkeServer.Openapi.Responses

  alias OpenApiSpex.{Operation, Reference}
  @mailer_module Application.get_env(:arke_server, :mailer_module)

  defp data_as_klist(data) do
    Enum.map(data, fn {key, value} -> {String.to_existing_atom(key), value} end)
  end

  defp get_review_email() do
    case System.get_env("APP_REVIEW_EMAIL") do
      nil -> []
      data -> String.split(data, ",") |> Enum.map(&String.trim(&1))
    end
  end

  defp get_review_code() do
    System.get_env("APP_REVIEW_CODE", "1234")
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
        @mailer_module.signup(conn,params,mode: "otp", unit: otp,code: otp.data.code)

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
          review_code = get_review_code()
          @mailer_module.signin(conn,member, mode: "otp", code: review_code)
          ResponseManager.send_resp(conn, 200, data, "OTP send successfully")
        else
          case Otp.generate(project, member.id, "signin") do
            {:ok, otp} ->
              @mailer_module.signin(conn,member,mode: "otp", unit: otp,code: otp.data.code)
              ResponseManager.send_resp(conn, 200, data, "OTP send successfully")

            {:error, errors} ->
              ResponseManager.send_resp(conn, 401, nil, errors)
          end
        end

      {:error, error} ->
        ResponseManager.send_resp(conn, 401, nil, error)
    end
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
          if otp == get_review_code() do
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
          code: get_review_code(),
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
        @mailer_module.reset_password(conn,member,mode: "otp",unit: otp,code: otp.data.code)

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
            @mailer_module.reset_password(conn,user,mode: "email", unit: unit, endpoint: endpoint)
            ResponseManager.send_resp(conn, 200, nil)
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
