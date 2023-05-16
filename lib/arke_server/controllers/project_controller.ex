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

defmodule ArkeServer.ProjectController do
  @moduledoc """
      Documentation for  `ArkeServer.ProjectController`.
  """

  use ArkeServer, :controller
  alias Arke.{QueryManager, LinkManager, StructManager}
  alias Arke.Boundary.ArkeManager
  alias UnitSerializer
  alias ArkeServer.ResponseManager

  defp data_as_klist(data) do
    Enum.map(data, fn {key, value} -> {String.to_existing_atom(key), value} end)
  end

  @doc """
       Create a new unit
       """ && false
  def create(conn, params) do
    # all arkes struct and gen server are on :arke_system so it won't be changed to project
    arke = ArkeManager.get(:arke_project, :arke_system)

    QueryManager.create(:arke_system, arke, data_as_klist(params))
    |> case do
      {:ok, unit} ->
        ResponseManager.send_resp(conn, 200, %{content: StructManager.encode(unit, type: :json)})

      {:error, error} ->
        ResponseManager.send_resp(conn, 400, nil, error)
    end
  end

  @doc """
       Update an unit
       """ && false
  def update(%Plug.Conn{body_params: params} = conn, %{"unit_id" => unit_id}) do
    arke = ArkeManager.get(:arke_project, :arke_system)
    unit = QueryManager.get_by(project: :arke_system, arke: arke, id: unit_id)

    QueryManager.update(unit, data_as_klist(params))
    |> case do
      {:ok, unit} ->
        ResponseManager.send_resp(conn, 200, %{content: StructManager.encode(unit, type: :json)})

      {:error, error} ->
        ResponseManager.send_resp(conn, 400, nil, error)
    end
  end

  # delete
  @doc """
       Delete a unit
       """ && false
  def delete(conn, %{"unit_id" => unit_id}) do
    arke = ArkeManager.get(:arke_project, :arke_system)
    unit = QueryManager.get_by(project: :arke_system, arke: arke, id: unit_id)

    QueryManager.delete(:arke_system, unit)
    |> case do
      {:ok, nil} -> ResponseManager.send_resp(conn, 204)
      {:error, error} -> ResponseManager.send_resp(conn, 400, nil, error)
    end
  end

  @doc """
       Get a units of arke_project
       """ && false
  def index(conn, %{}) do
    arke_list = QueryManager.filter_by(project: :arke_system, arke: :arke_project)
    ResponseManager.send_resp(conn, 200, %{items: StructManager.encode(arke_list, type: :json)})
  end

  @doc """
       It returns a unit
       """ && false
  def show(conn, %{"unit_id" => unit_id}) do
    arke = ArkeManager.get(:arke_project, :arke_system)
    unit = QueryManager.get_by(project: :arke_system, arke: arke, id: unit_id)
    ResponseManager.send_resp(conn, 200, %{content: StructManager.encode(unit, type: :json)})
  end
end
