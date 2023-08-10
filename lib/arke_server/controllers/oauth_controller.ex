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
  alias ArkeServer.OAuth.{Google, Facebook}

  plug(Ueberauth,
    otp_app: :arke_server,
    base_path: "/lib/auth/signin"
  )

  # --- Openapi deps ---
  alias ArkeServer.Openapi.Responses
  alias OpenApiSpex.{Operation, Reference}
  # --- end Openapi deps ---
  alias ArkeServer.ResponseManager
  alias ArkeAuth.Core.{Auth}
  alias Arke.Boundary.ArkeManager
  alias Arke.LinkManager
  alias Arke.{QueryManager}
  alias Arke.Utils.ErrorGenerator, as: Error

  # ------- start OPENAPI spec -------
  def open_api_operation(action) do
    unless(action in [:callback]) do
      operation = String.to_existing_atom("#{action}_operation")
      apply(__MODULE__, operation, [])
    end
  end

  def request_operation() do
    %Operation{
      tags: ["OAuth"],
      summary: "Init OAuth flow",
      parameters: [%Reference{"$ref": "#/components/parameters/provider"}],
      description:
        "Start the OAuth flow for the given provider. Available providers are: `apple`, `github`, `facebook`, `google`",
      operationId: "ArkeServer.AuthController.request",
      security: [],
      responses: Responses.get_responses([302, 404])
    }
  end

  def verify_operation() do
    %Operation{
      tags: ["OAuth"],
      summary: "Verify",
      description:
        "Verify the given token after a client sign-in. Available providers are: `apple`, `github`, `facebook`, `google`",
      operationId: "ArkeServer.AuthController.verify",
      security: [],
      responses: Responses.get_responses([302, 404])
    }
  end

  # ------- end OPENAPI spec -------

  # This is the fallback if the given provider does not exists.
  # Usually it is used for the `identity` provider (username, password)
  def request(conn, _params) do
    ResponseManager.send_resp(conn, 404, nil)
  end

  def verify(
        %Plug.Conn{query_params: %{"token" => token}} = conn,
        %{"provider" => "google"} = _params
      ) do
    with {:ok, data} <- Google.validate_token(token),
         {:ok, body} <- init_oauth_flow(data) do
      ResponseManager.send_resp(conn, 200, %{content: body})
    else
      {:error, msg} ->
        ResponseManager.send_resp(conn, 400, msg)
    end
  end

  def verify(
        %Plug.Conn{query_params: %{"token" => token}} = conn,
        %{"provider" => "facebook"} = _params
      ) do
    with {:ok, data} <- Facebook.validate_token(token),
         {:ok, body} <- init_oauth_flow(data) do
      ResponseManager.send_resp(conn, 200, %{content: body})
    else
      {:error, msg} ->
        ResponseManager.send_resp(conn, 400, msg)
    end
  end

  def verify(conn, _params) do
    {:error, msg} = Error.create(:auth, "invalid token/provider")
    ResponseManager.send_resp(conn, 400, msg)
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params),
    do: ResponseManager.send_resp(conn, 400)

  def callback(
        %{assigns: %{ueberauth_auth: %{provider: provider} = auth}, req_headers: header} = conn,
        _params
      ) do
    oauth_provider_supported =
      GroupManager.get(:oauth_provider, :arke_system).data.arke_list
      |> Enum.into([], fn unit -> String.replace(to_string(unit.id), "oauth_", "") end)

    case String.downcase(to_string(provider)) in oauth_provider_supported do
      true ->
        case init_oauth_flow(auth) do
          {:ok, body} -> ResponseManager.send_resp(conn, 200, %{content: body})
          {:error, msg} -> ResponseManager.send_resp(conn, 400, msg)
        end

      false ->
        {:error, msg} =
          Error.create(:auth, "the supported OAuth providers are: #{oauth_provider_supported}")

        ResponseManager.send_resp(conn, 400, msg)
    end
  end

  defp init_oauth_flow(auth_info) do
    with {:ok, user} <- check_oauth(auth_info),
         {:ok, user, access_token, refresh_token} <-
           Auth.create_tokens(user) do
      content =
        Map.merge(Arke.StructManager.encode(user, type: :json), %{
          access_token: access_token,
          refresh_token: refresh_token
        })

      {:ok, content}
    else
      {:error, reason} -> {:error, reason}
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
    updated_data = Map.put(user_data, :password, pwd) |> Map.put(:type, "customer")
    QueryManager.create(:arke_system, user_model, updated_data)
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
