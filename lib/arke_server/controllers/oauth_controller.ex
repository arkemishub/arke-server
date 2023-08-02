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

  plug(Ueberauth,
    otp_app: :arke_server,
    base_path: "/lib/auth/signin"
  )

  # --- Openapi deps ---
  alias ArkeServer.Openapi.Responses
  alias OpenApiSpex.{Operation, Reference}
  # --- end Openapi deps ---
  alias Ueberauth.Strategy.Helpers
  alias ArkeServer.ResponseManager
  alias ArkeAuth.Core.{Auth}
  alias Arke.Boundary.ArkeManager
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

  # ------- end OPENAPI spec -------

  # This is the fallback if the given provider does not exists.
  # Usually it is used for the `identity` provider (username, password)
  def request(conn, _params) do
    ResponseManager.send_resp(conn, 404, nil)
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params),
    do: ResponseManager.send_resp(conn, 400)

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    username = UUID.uuid1(:hex)
    email = "#{username}@foo.domain"
    pwd = UUID.uuid4()

    IO.inspect(auth, label: "auth12")

    user_data = %{
      first_name: auth.info.first_name,
      last_name: auth.info.last_name,
      email: email,
      username: username,
      phone_number: Map.get(auth.info, :phone, nil),
      password: pwd,
      type: "customer",
      oauth_id: to_string(auth.uid),
      metadata: %{"oauth" => %{"provider" => auth.provider}}
    }

    with {:ok, user} <- check_user(user_data),
         {:ok, user, access_token, refresh_token} <-
           Auth.create_tokens(user) do
      content =
        Map.merge(Arke.StructManager.encode(user, type: :json), %{
          access_token: access_token,
          refresh_token: refresh_token
        })

      ResponseManager.send_resp(conn, 200, %{content: content})
    else
      {:error, reason} -> ResponseManager.send_resp(conn, 400, nil, reason)
    end
  end

  defp check_user(user_data) do
    case QueryManager.get_by(project: :arke_system, oauth_id: user_data.oauth_id) do
      nil ->
        user_model = ArkeManager.get(:user, :arke_system)
        QueryManager.create(:arke_system, user_model, user_data)

      user ->
        {:ok, user}
    end
  end
end
