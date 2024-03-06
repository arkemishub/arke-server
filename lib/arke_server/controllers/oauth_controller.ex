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
  alias Arke.Boundary.GroupManager

  alias ArkeServer.ResponseManager
  alias ArkeAuth.Core.{Auth}
  alias Arke.Boundary.ArkeManager
  alias Arke.LinkManager
  alias Arke.{QueryManager}
  alias Arke.Utils.ErrorGenerator, as: Error

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
    case init_oauth_flow(auth, provider) do
      {:ok, body} -> ResponseManager.send_resp(conn, 200, %{content: body})
      {:error, msg} ->
        ResponseManager.send_resp(conn, 400, msg)
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


  # ------- Client Side -------

  # ------- Using redirects -------

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params),
    do: ResponseManager.send_resp(conn, 400)

  def callback(
        %{assigns: %{ueberauth_auth: %{provider: provider} = auth}, req_headers: _header} = conn,
        _params
      ) do
    case init_oauth_flow(auth, provider) do
      {:ok, body} -> ResponseManager.send_resp(conn, 200, %{content: body})
      {:error, msg} -> ResponseManager.send_resp(conn, 400, msg)
    end
  end

  # ------- end Using redirects -------

  defp init_oauth_flow(auth_info, provider) do
    with {:ok, nil} <- check_provider(provider),
         {:ok, user} <- check_oauth(auth_info),
         {:ok, user, access_token, refresh_token} <-
           Auth.create_tokens(user,true) do
      # todo: if the member exists create different token (set false instead of true)
      content =
        Map.merge(Arke.StructManager.encode(user, type: :json), %{
          access_token: access_token,
          refresh_token: refresh_token,
          uncompleted_data: true
        })

      {:ok, content}
    else
      {:error, reason} -> {:error, reason}
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
    username = UUID.uuid1(:hex)
    email = auth.info.email || "#{username}@foo.domain"
    oauth_id = to_string(auth.uid)
    provider = auth.provider

    oauth_user_data = %{
      first_name: auth.info.first_name,
      last_name: auth.info.last_name,
      email: email,
      oauth_id: oauth_id,
      username: username
    }

    check_oauth_user(oauth_user_data, provider)
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
        case QueryManager.query(project: :arke_system)
             |> QueryManager.link(oauth_unit,
               depth: 1,
               direction: :parent,
               type: "oauth"
             )
             |> QueryManager.all() do
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
          userList ->
            {:ok, List.first(userList)}
        end
    end
  end
end
