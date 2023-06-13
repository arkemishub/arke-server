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
             """ && false
  use ArkeServer, :router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(ArkeServer.Plugs.NotAuthPipeline)
  end

  pipeline :auth_api do
    plug(:accepts, ["json"])
    plug(ArkeServer.Plugs.AuthPipeline)
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
    pipe_through([:openapi])

    scope "/auth" do
      post("/signin", AuthController, :signin)
      post("/signup", AuthController, :signup)

      pipe_through(:api)
      post("/refresh", AuthController, :refresh)
      post("/verify", AuthController, :verify)
    end

    # ↑ Not auth endpoint (no access token)
    pipe_through([:auth_api])
    # ↓ Auth endpoint (no access token)

    post("/auth/change_password", AuthController, :change_password)

    # -------- PROJECT --------

    scope "/arke_project" do
      get("/unit", ProjectController, :get_all_unit)
      get("/unit/:unit_id", ProjectController, :get_unit)
      put("/unit/:unit_id", ProjectController, :update)
      post("/unit", ProjectController, :create)
      delete("/unit/:unit_id", ProjectController, :delete)
    end

    # ↑ Do not need arke-project-key
    pipe_through([:project])
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

    # -------- POST --------

    post("/:arke_id/unit", ArkeController, :create)

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

    delete("/:arke_id/unit/:unit_id", ArkeController, :delete)

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

      # UNIT
      scope "/unit" do
        get("/", ArkeController, :get_all_unit)
        get("/:unit_id", ArkeController, :get_unit)

        # TOPOLOGY
        scope "/:arke_unit_id" do
          get("/link/:direction", TopologyController, :get_node)
          get("/struct", StructController, :get_unit_struct)
        end
      end
    end

    # GLOBAL SEARCH
    get("/unit", UnitController, :search)
  end
end
