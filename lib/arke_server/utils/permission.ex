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

defmodule ArkeServer.Utils.Permission do
  alias Arke.QueryManager
  alias Arke.Boundary.ArkeManager
  alias ArkeServer.Utils.{QueryFilters}

  alias Arke.Utils.ErrorGenerator, as: Error

  def get_permission(conn, arke_id, action) do
    member = ArkeAuth.Guardian.Plug.current_resource(conn)
    project = conn.assigns[:arke_project]
    arke = ArkeManager.get(arke_id, project)

    case ArkeAuth.Core.Member.get_permission(member, arke) do
      {:ok, permission} ->
        case Map.get(permission, action, false) do
          true ->
            permission = get_permission_filter(conn, member, permission)
            {:ok, permission}

          false ->
            {:error, :not_authorized}
        end

      {:error, nil} ->
        {:error, :not_authorized}
    end
  end

  defp get_permission_filter(conn, member, %{filter: nil} = permission), do: permission

  defp get_permission_filter(conn, member, permission) do
    filter = String.replace(permission.filter, "{{arke_member}}", Atom.to_string(member.id))

    case QueryFilters.get_from_string(conn, filter) do
      {:ok, data} -> Map.put(permission, :filter, data)
      {:error, _msg} -> Map.put(permission, :filter, nil)
    end
  end
end



