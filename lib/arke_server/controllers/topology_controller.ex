defmodule ArkeServer.TopologyController do
  @moduledoc """
             Documentation for  `ArkeServer.TopologyController`.
             """ && false

  use ArkeServer, :controller

  alias Arke.{QueryManager, LinkManager, StructManager}
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

  def get_node_operation() do
    %Operation{
      tags: ["Topology"],
      summary: "Get node",
      description: "Get all elements (limited by depth parameter) linked to the given Unit",
      operationId: "ArkeServer.TopologyController.get_node",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
        Operation.parameter(:arke_unit_id, :path, :string, "Parent Unit ID", required: true),
        %Reference{"$ref": "#/components/parameters/link_id"},
        Operation.parameter(:direction, :path, :string, "Direction where to get the node",
          example: "child",
          required: true
        ),
        %Reference{"$ref": "#/components/parameters/arke-project-key"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses(201)
    }
  end

  def create_node_operation() do
    %Operation{
      tags: ["Topology"],
      summary: "Create connection",
      description: "Create a link between two units",
      operationId: "ArkeServer.TopologyController.create_node",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
        Operation.parameter(:arke_unit_id, :path, :string, "Parent Unit ID", required: true),
        %Reference{"$ref": "#/components/parameters/link_id"},
        Operation.parameter(:arke_id_two, :path, :string, "Child Arke ID", required: true),
        Operation.parameter(:unit_id_two, :path, :string, "Child Arke ID", required: true),
        %Reference{"$ref": "#/components/parameters/arke-project-key"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses()
    }
  end

  def delete_node_operation() do
    %Operation{
      tags: ["Topology"],
      summary: "Delete connection",
      description: "Delete connection between two nodes",
      operationId: "ArkeServer.TopologyController.delete_node",
      parameters: [
        Operation.parameter(:arke_id, :path, :string, "Parent Arke ID", required: true),
        Operation.parameter(:arke_unit_id, :path, :string, "Parent Unit ID", required: true),
        %Reference{"$ref": "#/components/parameters/link_id"},
        Operation.parameter(:arke_id_two, :path, :string, "Child Arke ID", required: true),
        Operation.parameter(:unit_id_two, :path, :string, "Child Unit ID", required: true),
        %Reference{"$ref": "#/components/parameters/arke-project-key"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([200, 201])
    }
  end

  def add_parameter_operation() do
    %Operation{
      tags: ["Parameter"],
      summary: "Add parameter",
      description: "Add parameter to the given Arke",
      operationId: "ArkeServer.TopologyController.add_parameter",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
        %Reference{"$ref": "#/components/parameters/arke_parameter_id"},
        %Reference{"$ref": "#/components/parameters/arke-project-key"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([200, 201])
    }
  end

  # ------- end OPENAPI spec -------

  @doc """
            Get the unit linked to an Arke
       """ && false
  def get_node(conn, %{"arke_id" => _arke_id, "arke_unit_id" => _id, "direction" => direction}) do
    project = conn.assigns[:arke_project]
    direction = String.to_existing_atom(direction)
    depth = Map.get(conn.query_params, "depth", nil)
    link_type = Map.get(conn.query_params, "link_type", nil)
    offset = Map.get(conn.query_params, "offset", nil)
    limit = Map.get(conn.query_params, "limit", nil)
    order = Map.get(conn.query_params, "order", [])

    # TODO handle query parameter with plugs
    load_links = Map.get(conn.query_params, "load_links", "false") == "true"

    {count, units} =
      QueryManager.query(project: project)
      |> QueryManager.link(conn.assigns[:unit],
        depth: depth,
        direction: direction,
        type: link_type
      )
      |> QueryFilters.apply_query_filters(Map.get(conn.assigns, :filter))
      |> QueryOrder.apply_order(order)
      |> QueryManager.pagination(offset, limit)

    ResponseManager.send_resp(conn, 200, %{
      count: count,
      items: StructManager.encode(units, load_links: load_links, type: :json)
    })
  end

  @doc """
       Link two unit together
       """ && false
  def create_node(%Plug.Conn{body_params: params} = conn, %{
        "arke_id" => arke_id,
        "arke_id_two" => arke_id_two,
        "arke_unit_id" => parent_id,
        "link_id" => type,
        "unit_id_two" => child_id
      }) do
    project = conn.assigns[:arke_project]

    # TODO handle query parameter with plugs
    load_links = Map.get(conn.query_params, "load_links", "false") == "true"

    configuration =
      with true <- Map.has_key?(params, "configuration"),
           do: params["configuration"],
           else: (_ -> %{})

    parent = QueryManager.get_by(project: project, arke: arke_id, id: parent_id)
    child = QueryManager.get_by(project: project, arke: arke_id_two, id: child_id)

    LinkManager.add_node(project, parent, child, type, configuration)
    |> case do
      {:ok, unit} ->
        ResponseManager.send_resp(
          conn,
          201,
          StructManager.encode(unit, load_links: load_links, type: :json)
        )

      {:error, error} ->
        ResponseManager.send_resp(conn, 400, nil, error)
    end
  end

  @doc """
       Delete a connection between two units
       """ && false
  def delete_node(%Plug.Conn{body_params: params} = conn, %{
        "arke_id" => _arke_id,
        "arke_id_two" => _arke_id_two,
        "arke_unit_id" => parent,
        "link_id" => type,
        "unit_id_two" => child
      }) do
    project = conn.assigns[:arke_project]
    # link arke is only in :arke_system so it won't be changed right now
    #    link = ArkeManager.get :arke_link, :arke_system
    configuration =
      with true <- Map.has_key?(params, "configuration"),
           do: params["configuration"],
           else: (_ -> %{})

    with {:ok, nil} <- LinkManager.delete_node(project, parent, child, type, configuration) do
      ResponseManager.send_resp(conn, 204)
    else
      _ -> ResponseManager.send_resp(conn, 500, "")
    end
  end

  @doc """
       Associate a parameter to an Arke
       """ && false
  def add_parameter(conn, %{
        "arke_parameter_id" => parameter_id,
        "arke_id" => arke_id,
        "configuration" => configuration
      }) do
    project = conn.assigns[:arke_project]

    # TODO handle query parameter with plugs
    load_links = Map.get(conn.query_params, "load_links", "false") == "true"

    LinkManager.add_node(project, arke_id, parameter_id, "parameter", configuration)
    |> case do
      {:ok, unit} ->
        ResponseManager.send_resp(conn, 201, %{
          content: StructManager.encode(unit, load_links: load_links, type: :json)
        })

      {:error, error} ->
        ResponseManager.send_resp(conn, 400, nil, error)
    end
  end
end
