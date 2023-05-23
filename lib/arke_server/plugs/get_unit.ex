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

defmodule ArkeServer.Plugs.GetUnit do
  @moduledoc """
             Plug to get a unit from the id in the url
             """ && false
  import Plug.Conn
  alias Arke.{QueryManager}

  ## Once the project header has been set to mandatory retrieve it as follows:
  #  project = conn.assigns[:arke_project]

  def init(default), do: default

  def call(%Plug.Conn{path_info: path} = conn, default) do
    case Enum.filter(path, fn item -> String.contains?(item, "::") end) do
      [] -> single_unit(conn, default)
      items -> unit_list(conn, items, [])
    end
  end

  defp unit_list(conn, [], assignments) do
    case Enum.any?(assignments, &is_nil/1) or Enum.empty?(assignments) do
      true -> parse_unit(conn, nil)
      false -> parse_unit(conn, assignments)
    end
  end

  defp unit_list(conn, [head | tail], assignments) do
    project = conn.assigns[:arke_project]
    [arke_id, unit_id] = String.split(head, "::")
    unit = get_unit(conn, project, arke_id, unit_id)
    unit_list(conn, tail, [unit | assignments])
  end

  defp get_unit(conn, project, arke_id, unit_id) do
    try do
      case QueryManager.get_by(project: project, arke: arke_id, id: unit_id) do
        nil -> nil
        unit -> unit
      end
    rescue
      _ ->
        not_found(conn)
    end
  end

  def single_unit(
        %Plug.Conn{path_params: %{"unit_id" => id, "arke_id" => arke_id}} = conn,
        _default
      ) do
    project = conn.assigns[:arke_project]
    unit = get_unit(conn, project, arke_id, id)
    parse_unit(conn, unit)
  end

  def single_unit(
        %Plug.Conn{path_params: %{"arke_unit_id" => id, "arke_id" => arke_id}} = conn,
        _default
      ) do
    project = conn.assigns[:arke_project]
    unit = get_unit(conn, project, arke_id, id)
    parse_unit(conn, unit)
  end

  def single_unit(%Plug.Conn{path_params: %{"arke_id" => _}} = conn, _default) do
    conn
  end

  defp parse_unit(conn, unit) do
    case unit do
      nil ->
        not_found(conn)

      _ ->
        assign(conn, :unit, unit)
    end
  end

  defp not_found(conn) do
    ArkeServer.ResponseManager.send_resp(conn, 404, nil)
    |> Plug.Conn.halt()
  end
end
