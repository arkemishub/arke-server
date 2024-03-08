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

defmodule ArkeServer.StructController do
  @moduledoc """
              Documentation for`ArkeServer.StructController
             """
  use ArkeServer, :controller

  # Openapi request definition
  use ArkeServer.Openapi.Spec, module: ArkeServer.Openapi.StructControllerSpec


  alias Arke.{StructManager}
  alias Arke.Boundary.ArkeManager
  alias ArkeServer.ResponseManager

  alias ArkeServer.Openapi.Responses

  alias OpenApiSpex.{Operation, Reference}

  @doc """
       Get a struct of a unit
       """
  def get_unit_struct(conn, %{"arke_id" => arke_id, "arke_unit_id" => _id}) do
    project = conn.assigns[:arke_project]
    arke = ArkeManager.get(String.to_existing_atom(arke_id), project)
    arke = Arke.Core.Unit.update(arke, runtime_data: %{conn: conn})
    ResponseManager.send_resp(conn, 200, %{
      content: StructManager.get_struct(arke, conn.assigns[:unit], conn.query_params)
    })
  end

  @doc """
       Get a struct of an Arke
       """
  def get_arke_struct(conn, %{"arke_id" => id}) do
    project = conn.assigns[:arke_project]

    struct =
      ArkeManager.get(String.to_atom(id), project)
      |> Arke.Core.Unit.update(runtime_data: %{conn: conn})
      |> StructManager.get_struct(conn.query_params)

    ResponseManager.send_resp(conn, 200, %{content: struct})
  end
end
