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
             """ && false

  use ArkeServer, :controller
  alias Arke.{QueryManager, LinkManager, StructManager}
  alias Arke.Boundary.ArkeManager
  alias UnitSerializer
  alias ArkeServer.ResponseManager
  alias ArkeServer.Utils.{QueryFilters, QueryOrder}

  alias ArkeServer.Openapi.Responses

  alias OpenApiSpex.{Operation, Reference}

  # ------- start OPENAPI spec -------
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def get_unit_operation() do
    %Operation{
      tags: ["Unit"],
      summary: "Get unit",
      description: "Get all the units of an Arke",
      operationId: "ArkeServer.ArkeController.get_unit",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
        %Reference{"$ref": "#/components/parameters/unit_id"},
        %Reference{"$ref": "#/components/parameters/arke-project-key"},
        %Reference{"$ref": "#/components/parameters/limit"},
        %Reference{"$ref": "#/components/parameters/offset"},
        %Reference{"$ref": "#/components/parameters/order"},
        %Reference{"$ref": "#/components/parameters/filter"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([201, 204])
    }
  end

  def create_operation() do
    %Operation{
      tags: ["Unit"],
      summary: "Create Unit",
      description: "Create a new unit for the given Arke",
      operationId: "ArkeServer.ArkeController.create",
      parameters: [%Reference{"$ref": "#/components/parameters/arke-project-key"}],
      requestBody:
        OpenApiSpex.Operation.request_body(
          "Parameters to create a unit",
          "application/json",
          ArkeServer.Schemas.CreateUnitExample,
          required: true
        ),
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([200, 204])
    }
  end

  def update_operation() do
    %Operation{
      tags: ["Unit"],
      summary: "Login",
      description: "Provide credentials to login to the app",
      operationId: "ArkeServer.ArkeController.update",
      parameters: [%Reference{"$ref": "#/components/parameters/arke-project-key"}],
      requestBody:
        OpenApiSpex.Operation.request_body(
          "Parameters to login",
          "application/json",
          ArkeServer.Schemas.UserParams,
          required: true
        ),
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([201, 204])
    }
  end

  def delete_operation() do
    %Operation{
      tags: ["Unit"],
      summary: "Delete Unit",
      description: "Delete a specific Unit",
      operationId: "ArkeServer.ArkeController.delete",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
        %Reference{"$ref": "#/components/parameters/unit_id"},
        %Reference{"$ref": "#/components/parameters/arke-project-key"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([200, 201])
    }
  end

  def get_all_unit_operation() do
    %Operation{
      tags: ["Unit"],
      summary: "Get all",
      description: "Get all the unit for the given Arke",
      operationId: "ArkeServer.ArkeController.get_all_unit",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
        %Reference{"$ref": "#/components/parameters/arke-project-key"},
        %Reference{"$ref": "#/components/parameters/limit"},
        %Reference{"$ref": "#/components/parameters/offset"},
        %Reference{"$ref": "#/components/parameters/order"},
        %Reference{"$ref": "#/components/parameters/filter"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([201, 204])
    }
  end

  def get_groups_operation() do
    %Operation{
      tags: ["Group"],
      summary: "Get arke in group",
      description: "Get all available groups",
      operationId: "ArkeServer.ArkeController.get_groups",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
        %Reference{"$ref": "#/components/parameters/arke-project-key"},
        %Reference{"$ref": "#/components/parameters/limit"},
        %Reference{"$ref": "#/components/parameters/offset"},
        %Reference{"$ref": "#/components/parameters/order"},
        %Reference{"$ref": "#/components/parameters/filter"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([201, 204])
    }
  end

  # ------- end OPENAPI spec -------

  def data_as_klist(data) do
    Enum.map(data, fn {key, value} -> {String.to_existing_atom(key), value} end)
  end

  ## Once the project header has been set to mandatory retrieve it as follows:
  #  project = conn.assigns[:arke_project]

  @doc """
       It returns a unit
       """ && false
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
       """ && false
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
       """ && false
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
       """ && false
  def get_all_unit(conn, %{"arke_id" => id}) do
    project = conn.assigns[:arke_project]

    case get_permission(conn, id, :get) do
      {:ok, permission} ->
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

      {:error, :not_authorized} ->
        ResponseManager.send_resp(conn, 403, %{})
    end
  end

  @doc """
       Call Arke function
       """ && false
  def call_arke_function(conn, %{"arke_id" => arke_id, "function_name" => function_name}) do
    project = conn.assigns[:arke_project]

    case get_permission(conn, arke_id, :get) do
      {:ok, permission} ->
        arke =
          ArkeManager.get(arke_id, project) |> Arke.Core.Unit.update(runtime_data: %{conn: conn})

        case ArkeManager.call_func(arke, String.to_atom(function_name), [arke]) do
          {:error, error, status} -> ResponseManager.send_resp(conn, status, nil, error)
          {:error, error} -> ResponseManager.send_resp(conn, 404, nil, error)
          {:error, error, status} -> ResponseManager.send_resp(conn, status, nil, error)
          {:ok, content, status} -> ResponseManager.send_resp(conn, status, %{content: content})
          {:ok, content, status, messages} -> ResponseManager.send_resp(conn, status, %{content: content, messages: messages})
          res -> ResponseManager.send_resp(conn, 200, %{content: res})
        end

      {:error, :not_authorized} ->
        ResponseManager.send_resp(conn, 403, %{})
    end
  end

  @doc """
       Call Unit function
       """ && false
  def call_unit_function(conn, %{
        "arke_id" => arke_id,
        "unit_id" => unit_id,
        "function_name" => function_name
      }) do
    project = conn.assigns[:arke_project]

    case get_permission(conn, arke_id, :get) do
      {:ok, permission} ->
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

      {:error, :not_authorized} ->
        ResponseManager.send_resp(conn, 403, %{})
    end
  end

  @doc """
       Get Arke groups
       """ && false
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

  defp get_permission(conn, arke_id, action) do
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
