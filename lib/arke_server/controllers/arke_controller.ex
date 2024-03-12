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

defmodule ArkeServer.ArkeController do
  @moduledoc """
             Documentation for  `ArkeServer.ArkeController`.
             """

  use ArkeServer, :controller

  # Openapi request definition
  use ArkeServer.Openapi.Spec, module: ArkeServer.Openapi.ArkeControllerSpec

  alias Arke.{QueryManager, LinkManager, StructManager}
  alias Arke.Boundary.ArkeManager
  alias UnitSerializer
  alias ArkeServer.ResponseManager
  alias ArkeServer.Utils.{QueryFilters, QueryOrder, Permission}

  alias ArkeServer.Openapi.Responses

  alias OpenApiSpex.{Operation, Reference}


  def data_as_klist(data) do
    Enum.map(data, fn {key, value} -> {String.to_existing_atom(key), value} end)
  end

  @doc """
       It returns a unit
       """ 
  def get_unit(conn, %{"unit_id" => _unit_id}) do
    # TODO handle query parameter with plugs
    load_links = Map.get(conn.query_params, "load_links", "false") == "true"
    load_values = Map.get(conn.query_params, "load_values", "false") == "true"
    load_files = Map.get(conn.query_params, "load_files", "false") == "true"

    ResponseManager.send_resp(conn, 200, %{
      content:
        StructManager.encode(conn.assigns[:unit],
          load_links: load_links,
          load_values: load_values,
          load_files: load_files,
          type: :json
        )
    })
  end

  @doc """
       Create a new unit
       """ 
  def create(%Plug.Conn{body_params: params} = conn, %{"arke_id" => id}) do
    # all arkes struct and gen server are on :arke_system so it won't be changed to project
    project = conn.assigns[:arke_project]
    params = Map.put(params, "runtime_data", %{conn: conn})
    arke = ArkeManager.get(String.to_atom(id), project)

    # TODO handle query parameter with plugs
    load_links = Map.get(conn.query_params, "load_links", "false") == "true"
    load_values = Map.get(conn.query_params, "load_values", "false") == "true"
    load_files = Map.get(conn.query_params, "load_files", "false") == "true"

    QueryManager.create(project, arke, data_as_klist(params))
    |> case do
      {:ok, unit} ->
        ResponseManager.send_resp(conn, 200, %{
          content:
            StructManager.encode(unit,
              load_links: load_links,
              load_values: load_values,
              load_files: load_files,
              type: :json
            )
        })

      {:error, error} ->
        ResponseManager.send_resp(conn, 400, nil, error)
    end
  end

  # delete
  @doc """
       Delete a unit
       """ 
  def delete(conn, %{"unit_id" => _unit_id, "arke_id" => _arke_id}) do
    project = conn.assigns[:arke_project]

    QueryManager.delete(project, conn.assigns[:unit])
    |> case do
      {:ok, nil} -> ResponseManager.send_resp(conn, 204)
      {:error, error} -> ResponseManager.send_resp(conn, 400, nil, error)
    end
  end

  @doc """
       Get units
       """ 
  def get_all_unit(conn, %{"arke_id" => id}) do
    project = conn.assigns[:arke_project]
    permission = conn.assigns[:permission_filter] || %{filter: nil}

      member = ArkeAuth.Guardian.Plug.current_resource(conn)

      offset = Map.get(conn.query_params, "offset", nil)
      limit = Map.get(conn.query_params, "limit", nil)
      order = Map.get(conn.query_params, "order", [])

      # TODO handle query parameter with plugs
      load_links = Map.get(conn.query_params, "load_links", "false") == "true"
      load_values = Map.get(conn.query_params, "load_values", "false") == "true"
      load_files = Map.get(conn.query_params, "load_files", "false") == "true"
      {count, units} =
        QueryManager.query(project: project, arke: id)
        |> QueryFilters.apply_query_filters(Map.get(conn.assigns, :filter))
        |> QueryFilters.apply_query_filters(permission.filter)
        |> QueryFilters.apply_member_child_only(member, Map.get(permission, :child_only, false))
        |> handle_coordinates_filter(conn)
        |> QueryOrder.apply_order(order)
        |> QueryManager.pagination(offset, limit)

      ResponseManager.send_resp(conn, 200, %{
        count: count,
        items:
          StructManager.encode(units,
            load_links: load_links,
            load_values: load_values,
            load_files: load_files,
            type: :json
          )
      })
  end

  defp handle_coordinates_filter(query, conn) do

    radius = parse_coordinate(Map.get(conn.query_params, "radius", 30))
    latitude = parse_coordinate(Map.get(conn.query_params, "latitude", nil))
    longitude = parse_coordinate(Map.get(conn.query_params, "longitude", nil))

    case latitude == nil or longitude == nil do
      true -> query
      false ->
        {lat_nord, lat_sud, lon_est, lon_ovest} = calculate_coordinates(latitude, longitude, radius)
        query
        |> QueryManager.where(latitude__gte: lat_sud, latitude__lte: lat_nord)
        |> QueryManager.where(longitude__gte: lon_est, latitude__lte: lon_ovest)
    end
  end

  defp parse_coordinate(c) when is_binary(c), do: String.to_float(c)
  defp parse_coordinate(c), do: c

  defp calculate_coordinates(latitude, longitude, radius) do

    latitude_to_km = 110.574
    longitude_to_km = 111.32
    radius = radius

    delta_lat = radius / latitude_to_km
    delta_lon = radius / (longitude_to_km * :math.cos(latitude))

    lat_nord = latitude + delta_lat
    lat_sud = latitude - delta_lat
    lon_est = longitude + delta_lon
    lon_ovest = longitude - delta_lon

    {lat_nord, lat_sud, lon_est, lon_ovest}
  end

  @doc """
       Call Arke function
       """ 
  def call_arke_function(conn, %{"arke_id" => arke_id, "function_name" => function_name}) do
    project = conn.assigns[:arke_project]
    permission = conn.assigns[:permission_filter] || %{filter: nil}
    arke =
      ArkeManager.get(arke_id, project) |> Arke.Core.Unit.update(runtime_data: %{conn: conn})

    case ArkeManager.call_func(arke, String.to_atom(function_name), [arke]) do
      {:error, error, status} -> ResponseManager.send_resp(conn, status, nil, error)
      {:error, error} -> ResponseManager.send_resp(conn, 404, nil, error)
      {:ok, content, status} -> ResponseManager.send_resp(conn, status, %{content: content})
      {:ok, content, status, messages} -> ResponseManager.send_resp(conn, status, %{content: content}, messages)
      res -> ResponseManager.send_resp(conn, 200, %{content: res})
    end
  end

  @doc """
       Call Unit function
       """ 
  def call_unit_function(conn, %{
        "arke_id" => arke_id,
        "unit_id" => unit_id,
        "function_name" => function_name
      }) do
    project = conn.assigns[:arke_project]
    permission = conn.assigns[:permission_filter] || %{filter: nil}

    arke =
      ArkeManager.get(arke_id, project) |> Arke.Core.Unit.update(runtime_data: %{conn: conn})

    unit =
      QueryManager.query(project: project, arke: arke)
      |> QueryManager.where(id: unit_id)
      |> QueryFilters.apply_query_filters(permission.filter)
      |> QueryManager.one()

    case unit do
      %Arke.Core.Unit{} = unit ->
        case ArkeManager.call_func(arke, String.to_atom(function_name), [arke, unit]) do
          {:error, error, status} -> ResponseManager.send_resp(conn, status, nil, error)
          {:error, error} -> ResponseManager.send_resp(conn, 404, nil, error)
          {:ok, content, status} -> ResponseManager.send_resp(conn, status, %{content: content})
          {:ok, content, status, messages} -> ResponseManager.send_resp(conn, status, %{content: content}, messages)
          res -> ResponseManager.send_resp(conn, 200, %{content: res})
        end

      nil ->
        ResponseManager.send_resp(conn, 404, %{})
    end

  end

  @doc """
       Get Arke groups
       """ 
  def get_groups(conn, %{"arke_id" => id}) do
    project = conn.assigns[:arke_project]
    offset = Map.get(conn.query_params, "offset", nil)
    limit = Map.get(conn.query_params, "limit", nil)
    order = Map.get(conn.query_params, "order", [])
    arke = ArkeManager.get(id, project)

    {count, units} =
      QueryManager.query(project: project, arke: :group)
      |> QueryManager.link(arke, direction: :parent, type: "group")
      |> QueryFilters.apply_query_filters(Map.get(conn.assigns, :filter))
      |> QueryOrder.apply_order(order)
      |> QueryManager.pagination(offset, limit)

    ResponseManager.send_resp(conn, 200, %{
      count: count,
      items: StructManager.encode(units, type: :json)
    })
  end
end
