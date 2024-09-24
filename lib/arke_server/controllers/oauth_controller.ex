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

defmodule ArkeServer.OAuthController do
  @moduledoc """
  Auth controller responsible for handling Ueberauth responses
  """

  import Plug.Conn
  use ArkeServer, :controller

  # Openapi request definition
  use ArkeServer.Openapi.Spec, module: ArkeServer.Openapi.OAuthControllerSpec


  alias Arke.Boundary.GroupManager

  alias ArkeServer.ResponseManager
  alias ArkeAuth.Core.{Auth}
  alias Arke.Boundary.ArkeManager
  alias Arke.LinkManager
  alias Arke.{QueryManager}
  alias Arke.Utils.ErrorGenerator, as: Error
  alias Arke.Core.Unit
  alias ArkeServer.AuthController
  # This is the fallback if the given provider does not exists.
  # Usually it is used for the `identity` provider (username, password)
  def request(conn, _params) do
    ResponseManager.send_resp(conn, 404, nil)
  end

  # ------- Client Side -------
  # The login happens client_side only the token is sent to the REST API

  def handle_client_login(
        %{assigns: %{arke_server_oauth: %{provider: provider} = auth}, req_headers: _header} =
          conn,
        _params
      ) do
    project = conn.assigns[:arke_project]
    case init_oauth_flow(project,auth, provider) do
      {:ok, body,oauth_member} ->
        member = QueryManager.get_by(project: project, id: oauth_member.id)
        handle_member_login(conn,member)
        ResponseManager.send_resp(conn, 200, %{content: body})
      {:error,[%{context: "auth", message: "unauthorized"}]=msg} -> ResponseManager.send_resp(conn, 401, msg)
      {:error, msg} -> ResponseManager.send_resp(conn, 400, msg)
    end
  end

  def handle_client_login(
        %{assigns: %{arke_server_oauth_failure: msg}} = conn,
        _params
      ) do
    ResponseManager.send_resp(conn, 400, msg)
  end

  def handle_client_login(conn, _params) do
    {:error, msg} = Error.create(:auth, "invalid token/provider")
    ResponseManager.send_resp(conn, 400, msg)
  end

  def handle_create_member(
    %Plug.Conn{body_params: params}=conn,
        %{"member" => member_id, "provider" => provider}=_all_params
      ) do
    user_resource = ArkeAuth.SSOGuardian.Plug.current_resource(conn)
    user = QueryManager.get_by(project: :arke_system, arke_id: :user,id: user_resource.id)
    project = conn.assigns[:arke_project]
    provider_arke_id = String.to_existing_atom("oauth_#{provider}")
    enable_sso_group = GroupManager.get(:enable_sso,project)
    # check if the given member_id is enable to sso login
    # check if the user has any oauth link
    # check if one of the oauth link has the arke_id equal to the given provider
    with true <- member_id in (GroupManager.get_arke_list(enable_sso_group) |> Enum.map(fn ak -> to_string(ak.id)end)),
         [_data] = link_list <- get_link(user,:child),
         %Unit{}=_unit <- Enum.find(link_list, fn link_unit -> link_unit.arke_id == provider_arke_id end) do
      case check_member(project,user) do
        # member does not exists so create one
        {:ok,nil} ->
        case create_member(project,user,params,member_id) do
          {:ok,member} ->
            {:ok, resource_member, access_token, refresh_token} = Auth.create_tokens(member,"default")
            content = create_response_body(resource_member,access_token,refresh_token,false)
            AuthController.mailer_module().signup(conn,resource_member, mode: "oauth",member: resource_member,response_body: content)
            ResponseManager.send_resp(conn, 200, content)
          err -> ResponseManager.send_resp(conn, 400, err)
        end
        # member exists and it is active
        {:ok, resource_member, access_token, refresh_token} ->
          content = create_response_body(resource_member,access_token,refresh_token,false)
          AuthController.mailer_module().signup(conn,resource_member, mode: "oauth",member: resource_member,response_body: content)
          ResponseManager.send_resp(conn, 200, content)
        {:error, reason} ->
          {:error, reason}
      end
      else nil -> # there are no units associated with that provider or the provider does not exist
            # in any of the unit sso associated with the user
        {:error, msg} = Error.create(:sso, "invalid provider")
        ResponseManager.send_resp(conn, 400, msg)
      false -> {:error, msg} = Error.create(:sso, "invalid member")
               ResponseManager.send_resp(conn, 400, msg) # sso not enabled for the given member
    end
  end

  def handle_create_member(
         conn,
        _params
      ) do
    {:error, msg} = Error.create(:auth, "invalid token/provider")
    ResponseManager.send_resp(conn, 400, msg)
  end


  # ------- Client Side -------

  # ------- Using redirects -------

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params),
    do: ResponseManager.send_resp(conn, 400)

  def callback(
        %{assigns: %{ueberauth_auth: %{provider: provider} = auth}, req_headers: _header} = conn,
        _params
      ) do
    project = conn.assigns[:arke_project]
    case init_oauth_flow(project,auth, provider) do
      {:ok, body,_member} ->
        ResponseManager.send_resp(conn, 200, %{content: body})
      {:error, msg} -> ResponseManager.send_resp(conn, 400, msg)
    end
  end

  # ------- end Using redirects -------

  defp init_oauth_flow(project,auth_info, provider) do
    with {:ok, nil} <- check_provider(provider),
         {:ok, user} <- check_oauth(auth_info) do
         case check_member(project,user) do
           #if member does not exists creat a SSO token
            {:ok,nil} -> {:ok, user, access_token, refresh_token} = Auth.create_tokens(user,"sso")
                content = create_response_body(user,access_token,refresh_token,true)
                {:ok, content,user}
                # if exists and is active authenticate the user
            {:ok, resource_member, access_token, refresh_token} ->

              content = create_response_body(resource_member,access_token,refresh_token,false)
              {:ok, content,resource_member}
           {:error, reason} ->
             {:error, reason}
         end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_provider(provider) do
    oauth_provider_supported =
      GroupManager.get(:oauth_provider, :arke_system).data.arke_list
      |> Enum.into([], fn unit -> String.replace(to_string(unit.id), "oauth_", "") end)

    case String.downcase(to_string(provider)) in oauth_provider_supported do
      true ->
        {:ok, nil}

      false ->
        Error.create(
          :auth,
          "the supported OAuth providers are: #{Enum.join(oauth_provider_supported, ", ")}"
        )
    end
  end

  defp check_oauth(auth) do
    username = auth.info.email || UUID.uuid1(:hex)
    email = auth.info.email || "#{username}@foo.domain"
    oauth_id = to_string(auth.uid)
    provider = auth.provider

    oauth_user_data = %{
      first_name: auth.info.first_name,
      last_name: auth.info.last_name,
      email: String.downcase(email),
      oauth_id: oauth_id,
      username: username
    }

    check_oauth_user(oauth_user_data, provider)
  end

  defp create_response_body(resource,access_token,refresh_token,uncompleted_data) do
    Map.merge(Arke.StructManager.encode(resource, type: :json), %{
      access_token: access_token,
      refresh_token: refresh_token,
      uncompleted_data: uncompleted_data,
    })
  end

  defp create_member(project,user,params,member_id) do
    member_model = ArkeManager.get(String.to_atom(member_id),project)
    member_data = Map.put(params,"arke_system_user", to_string(user.id)) |> Map.put("email",user.data.email)
    new_data = for {key, val} <- member_data, into: %{}, do: {String.to_atom(key), val}
    QueryManager.create(project,member_model,new_data)
  end

  defp create_user(user_data) do
    user_model = ArkeManager.get(:user, :arke_system)
    pwd = UUID.uuid4()
    updated_data = Map.put(user_data, :password, pwd)
    email = Map.get(user_data,:email)
    case QueryManager.get_by(project: :arke_system, arke_id: :user, email: email) do
      nil -> QueryManager.create(:arke_system, user_model, updated_data)
      user -> {:ok,user}
    end

  end

  defp create_link(parent_id, child_id, provider) do
    LinkManager.add_node(:arke_system, to_string(parent_id), to_string(child_id), "oauth", %{
      provider: provider
    })
  end

  defp get_link(unit,direction) do
    QueryManager.query(project: :arke_system)
    |> QueryManager.link(unit,
         depth: 1,
         direction: direction,
         type: "oauth"
       )
    |> QueryManager.all()
  end

  # check if exists a user with the given data, if it has a link with another user or if it is new
  defp check_oauth_user(oauth_user_data, provider) do
    provider_arke_id = String.to_existing_atom("oauth_#{provider}")

    case QueryManager.get_by(
           project: :arke_system,
           arke_id: provider_arke_id,
           oauth_id: oauth_user_data.oauth_id
         ) do
      nil ->
        oauth_model = ArkeManager.get(provider_arke_id, :arke_system)
        # create the unit in the given provider and with the given uid

        with {:ok, oauth_unit} <- QueryManager.create(:arke_system, oauth_model, oauth_user_data),
             # create also a user
             {:ok, user} <- create_user(oauth_user_data),
             # connect the two
             {:ok, _link} <- create_link(user.id, oauth_unit.id, provider) do
          {:ok, user}
        else
          {:error, msg} -> {:error, msg}
          err -> raise err
        end

      oauth_unit ->
        # check if there is a link between the given oauth_unit and an user
        case get_link(oauth_unit,:parent) do
          [] ->
            # create a user and connect the two
            with {:ok, user} <- create_user(oauth_user_data),
                 {:ok, _link} <- create_link(user.id, oauth_unit.id, provider) do
              {:ok, user}
            else
              {:error, msg} ->
                {:error, msg}

              error ->
                raise error
            end

          # everything good log in
          user_list ->
            {:ok, List.first(user_list)}
        end
    end
  end

  defp check_member(project,user) do
    case Auth.get_project_member(project,user) do
      {:ok , member} -> Auth.create_tokens(Auth.format_member(member),"default")
      {:error, [%{context: "auth", message: "member not exists"}]} -> {:ok,nil} # if not exists return {:ok,nil}
      {:error, _msg} ->  Error.create(:auth, "unauthorized")
    end
  end

  defp handle_member_login(_conn,nil), do: nil
  defp handle_member_login(conn,member) do
    AuthController.update_member_access_time(member)
    AuthController.mailer_module().signin(conn,member, mode: "oauth")
  end
end
