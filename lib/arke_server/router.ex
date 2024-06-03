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

defmodule ArkeServer.Router do
  @moduledoc """
  Module where all the routes are defined. Too see run in the CLI: `mix phx.routes ArkeServer.Router`
  """
  use ArkeServer, :router

  ########################################################################
  ### START SSO PIPELINE #################################################
  ########################################################################

  pipeline :oauth do
    plug(ArkeServer.Plugs.OAuth,
      otp_app: :arke_server,
      base_path: "/lib/auth/signin"
    )
  end

  pipeline :sso_auth_api do
    plug(:accepts, ["json"])
    plug(ArkeServer.Plugs.SSOAuthPipeline)
  end

  ########################################################################
  ### END SSO PIPELINE ###################################################
  ########################################################################

  pipeline :api do
    plug(:accepts, ["json", "multipart"])
    plug(ArkeServer.Plugs.NotAuthPipeline)
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :auth_api do
    plug(:accepts, ["json", "multipart"])
    plug(ArkeServer.Plugs.Permission)
  end

  pipeline :project do
    plug(ArkeServer.Plugs.GetProject)
    plug(ArkeServer.Plugs.BuildFilters)
  end

  pipeline :get_unit do
    plug(ArkeServer.Plugs.GetUnit)
  end

  pipeline :openapi do
    plug(OpenApiSpex.Plug.PutApiSpec, module: ArkeServer.ApiSpec)
  end

  # ------ OPENAPI -------

  scope "/lib/doc" do
    get("/swaggerui", OpenApiSpex.Plug.SwaggerUI, path: "/lib/doc/openapi")

    pipe_through([:openapi])
    get("/openapi", OpenApiSpex.Plug.RenderSpec, [])
  end

  scope "/lib", ArkeServer do
    # -------- AUTH --------

    scope "/health" do
      get("ready", HealthController, :ready)
    end

    pipe_through([:openapi])

    scope "/auth" do
      pipe_through([:project])

      get("/signin", AuthController, :signin)
      post("/signin", AuthController, :signin)
      post("/:arke_id/signup", AuthController, :signup)
      post("/recover_password", AuthController, :recover_password)
      post("/reset_password", AuthController, :reset_password)
      post("/reset_password/:token", AuthController, :reset_password)

      scope "/signin/:provider" do
        pipe_through(:oauth)
        post("/", OAuthController, :handle_client_login)

        # endpoints below  are used only if we want to enable the redirect via backed
        # pipe_through(:browser)
        # get("/", OAuthController, :request)
        # get("/callback", OAuthController, :callback)
        # post("/callback", OAuthController, :callback)
      end

      scope "/:member/:provider" do
        pipe_through([:sso_auth_api])
        post("/", OAuthController, :handle_create_member)
      end

      post("/refresh", AuthController, :refresh)

      pipe_through(:auth_api)
      post("/verify", AuthController, :verify)
      post("/change_password", AuthController, :change_password)
    end

    # -------- PROJECT --------

    scope "/arke_project" do
      pipe_through([:auth_api])
      get("/unit", ProjectController, :get_all_unit)
      get("/unit/:unit_id", ProjectController, :get_unit)
      put("/unit/:unit_id", ProjectController, :update)
      post("/unit", ProjectController, :create)
      delete("/unit/:unit_id", ProjectController, :delete)
    end

    # ↑ Do not need arke-project-key
    # ↑ Not auth endpoint (no access token)
    pipe_through([:project, :auth_api])
    # ↓ Auth endpoint (access token)
    # ↓ Must have arke-project-key

    # GROUP
    scope "/group/:group_id" do
      get("/arke", GroupController, :get_arke)
      get("/struct", GroupController, :struct)
      get("/unit", GroupController, :get_unit)
      get("/unit/:unit_id", GroupController, :unit_detail)
    end

    pipe_through([:get_unit])
    # -------- PUT --------

    # UNIT
    put("/:arke_id/unit/:unit_id", UnitController, :update)
    put("/:arke_id/bulk/unit", UnitController, :update_bulk)

    put("/:arke_id/parameter/:arke_parameter_id", TopologyController, :update_parameter)

    put(
      "/:arke_id/unit/:arke_unit_id/link/:link_id/:arke_id_two/unit/:unit_id_two",
      TopologyController,
      :update_node
    )

    # -------- POST --------

    post("/:arke_id/unit", ArkeController, :create)
    post("/:arke_id/bulk/unit", ArkeController, :create_bulk)

    post("/:arke_id/parameter/:arke_parameter_id", TopologyController, :add_parameter)

    post(
      "/:arke_id/unit/:arke_unit_id/link/:link_id/:arke_id_two/unit/:unit_id_two",
      TopologyController,
      :create_node
    )

    # -------- DELETE --------
    delete(
      "/:arke_id/unit/:arke_unit_id/link/:link_id/:arke_id_two/unit/:unit_id_two",
      TopologyController,
      :delete_node
    )

    delete("/:arke_id/unit/bulk", ArkeController, :delete_bulk)
    delete("/:arke_id/unit/:unit_id", ArkeController, :delete)

    # -------- CALL FUNCTION --------

    get("/:arke_id/function/:function_name", ArkeController, :call_arke_function)
    get("/:arke_id/unit/:unit_id/function/:function_name", ArkeController, :call_unit_function)

    post("/:arke_id/function/:function_name", ArkeController, :call_arke_function)
    post("/:arke_id/unit/:unit_id/function/:function_name", ArkeController, :call_unit_function)

    get("/group/:group_id/function/:function_name", GroupController, :call_group_function)
    post("/group/:group_id/function/:function_name", GroupController, :call_group_function)

    # -------- PARAMETER --------
    get("/parameter/:parameter_id", ParameterController, :get_parameter_value)
    post("/parameter/:parameter_id", ParameterController, :add_link_parameter_value)
    put("/parameter/:parameter_id", ParameterController, :update_parameter_value)
    delete("/parameter/:parameter_id/:unit_id", ParameterController, :remove_link_parameter_value)

    # -------- GET --------

    # ARKE
    scope "/:arke_id" do
      get("/struct", StructController, :get_arke_struct)
      get("/group", ArkeController, :get_groups)
      get("/count", ArkeController, :get_all_unit_count)

      # UNIT
      scope "/unit" do
        get("/", ArkeController, :get_all_unit)
        get("/:unit_id", ArkeController, :get_unit)

        # TOPOLOGY
        scope "/:arke_unit_id" do
          get("/link/:direction", TopologyController, :get_node)
          get("/link/:direction/count", TopologyController, :get_node_count)
          get("/struct", StructController, :get_unit_struct)
        end
      end
    end

    # GLOBAL SEARCH
    get("/unit", UnitController, :search)
  end
end
