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

defmodule ArkeServer.Plugs.GetProject do
  @moduledoc """
             Plug to get the project from the request header
             """
  import Plug.Conn
  alias Arke.Utils.ErrorGenerator, as: Error

  @doc false
  def init(default), do: default
  @doc false
  def call(%Plug.Conn{req_headers: headers} = conn, _default) do
    with {:ok, unit} <- get_project_from_headers(headers) do
      # TODO Figure out whether to pass the unit directly instead of the id
      assign(conn, :arke_project, unit.id)
    else
      {:error, msg} ->
        ArkeServer.ResponseManager.send_resp(conn, 401, nil, msg)
        |> Plug.Conn.halt()
    end
  end

  defp get_project_from_headers(headers) do
    with [proj] <-
           Enum.filter(headers, fn {k, _} -> k == "arke-project-key" end) |> Keyword.values() do
      with nil <- Arke.QueryManager.get_by(project: :arke_system, arke: :arke_project, id: proj) do
        Error.create(:auth, "invalid project")
      else
        unit -> {:ok, unit}
      end
    else
      _ ->
        Error.create(:auth, "missing project header")
    end
  end
end
