defmodule ArkeServer.TopologyController do
  @moduledoc """
             Documentation for  `ArkeServer.TopologyController`.
             """

  use ArkeServer, :controller

  # Openapi request definition
  use ArkeServer.Openapi.Spec, module: ArkeServer.Openapi.TopologyControllerSpec


  alias Arke.{QueryManager, LinkManager, StructManager}
  alias Arke.Utils.ErrorGenerator, as: Error
  alias UnitSerializer
  alias ArkeServer.ResponseManager
  alias ArkeServer.Utils.{QueryFilters, QueryOrder}
  alias ArkeServer.Openapi.Responses

  alias OpenApiSpex.{Operation, Reference}

  @doc """
            Get the unit linked to an Arke
       """
  def get_node(conn, %{"arke_id" => _arke_id, "arke_unit_id" => _id, "direction" => direction}) do

    offset = Map.get(conn.query_params, "offset", nil)
    limit = Map.get(conn.query_params, "limit", nil)
    order = Map.get(conn.query_params, "order", [])

    # TODO handle query parameter with plugs
    load_links = Map.get(conn.query_params, "load_links", "false") == "true"
    load_values = Map.get(conn.query_params, "load_values", "false") == "true"

    {count, units} =
      handle_get_node_query(conn, direction)
      |> QueryOrder.apply_order(order)
      |> QueryManager.pagination(offset, limit)

    ResponseManager.send_resp(conn, 200, %{
      count: count,
      items:
        StructManager.encode(units, load_links: load_links, load_values: load_values, type: :json)
    })
  end

  defp handle_get_node_query(conn, direction) do
    project = conn.assigns[:arke_project]
    direction = String.to_existing_atom(direction)
    depth = Map.get(conn.query_params, "depth", nil)
    link_type = Map.get(conn.query_params, "link_type", nil)

    QueryManager.query(project: project)
    |> QueryManager.link(conn.assigns[:unit],
         depth: depth,
         direction: direction,
         type: link_type
       )
    |> QueryFilters.apply_query_filters(Map.get(conn.assigns, :filter))
  end

  def get_node_count(conn, %{"arke_id" => _arke_id, "arke_unit_id" => _id, "direction" => direction}) do

    count = handle_get_node_query(conn, direction)
            |> QueryManager.count()

    ResponseManager.send_resp(conn, 200, count)
  end

  @doc """
       Link two unit together
       """
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
    load_values = Map.get(conn.query_params, "load_values", "false") == "true"

    metadata = Map.get(params, "metadata", %{})

    LinkManager.add_node(project, parent_id, child_id, type, metadata)
    |> case do
      {:ok, unit} ->
        ResponseManager.send_resp(
          conn,
          201,
          StructManager.encode(unit, load_links: load_links, load_values: load_values, type: :json)
        )

      {:error, error} ->
        ResponseManager.send_resp(conn, 400, nil, error)
    end
  end

  @doc """
       Update metadata of an existing link
       """

  def update_node(%Plug.Conn{body_params: params} = conn, %{
        "arke_unit_id" => parent_id,
        "link_id" => type,
        "unit_id_two" => child_id
      }) do
    case Map.has_key?(params, "metadata") do
      true ->
        update_link(conn, parent_id, child_id, type, Map.get(params, "metadata"))

      false ->
        {:error, msg} = Error.create("link", "metadata is required")
        ResponseManager.send_resp(conn, 400, nil, msg)
    end
  end

  @doc """
       Delete a connection between two units
       """
  def delete_node(%Plug.Conn{body_params: params} = conn, %{
        "arke_id" => _arke_id,
        "arke_id_two" => _arke_id_two,
        "arke_unit_id" => parent_id,
        "link_id" => type,
        "unit_id_two" => child_id
      }) do
    project = conn.assigns[:arke_project]
    # link arke is only in :arke_system so it won't be changed right now
    #    link = ArkeManager.get :arke_link, :arke_system
    metadata = Map.get(params, "metadata", %{})

    with {:ok, nil} <- LinkManager.delete_node(project, parent_id, child_id, type, metadata) do
      ResponseManager.send_resp(conn, 204)
    else
      {:error, error} ->
        ResponseManager.send_resp(conn, 404, nil, error)
    end
  end

  @doc """
       Associate a parameter to an Arke
       """
  def add_parameter(%Plug.Conn{body_params: params} = conn, %{
        "arke_parameter_id" => parameter_id,
        "arke_id" => arke_id
      }) do
    project = conn.assigns[:arke_project]

    metadata = Map.get(params, "metadata", %{})

    # TODO handle query parameter with plugs
    load_links = Map.get(conn.query_params, "load_links", "false") == "true"
    load_values = Map.get(conn.query_params, "load_values", "false") == "true"

    LinkManager.add_node(project, arke_id, parameter_id, "parameter", metadata)
    |> case do
      {:ok, unit} ->
        ResponseManager.send_resp(conn, 201, %{
          content:
            StructManager.encode(unit,
              load_links: load_links,
              load_values: load_values,
              type: :json
            )
        })

      {:error, error} ->
        ResponseManager.send_resp(conn, 400, nil, error)
    end
  end

  @doc """
       Update an associated parameter of an Arke
       """
  def update_parameter(%Plug.Conn{body_params: params} = conn, %{
        "arke_parameter_id" => parameter_id,
        "arke_id" => arke_id
      }) do
    case Map.has_key?(params, "metadata") do
      true ->
        update_link(conn, arke_id, parameter_id, "parameter", Map.get(params, "metadata"))

      false ->
        {:error, msg} = Error.create("link", "metadata is required")
        ResponseManager.send_resp(conn, 400, nil, msg)
    end
  end

  defp update_link(conn, arke_id, parameter_id, type, metadata) do
    # TODO handle query parameter with plugs
    # TODO improve checks if permissions are being touched
    project = conn.assigns[:arke_project]

    load_links = Map.get(conn.query_params, "load_links", "false") == "true"
    load_values = Map.get(conn.query_params, "load_values", "false") == "true"

    LinkManager.update_node(
      project,
      arke_id,
      parameter_id,
      type,
      metadata
    )
    |> case do
      {:ok, unit} ->
        ResponseManager.send_resp(conn, 200, %{
          content:
            StructManager.encode(unit,
              load_links: load_links,
              load_values: load_values,
              type: :json
            )
        })

      {:error, error} ->
        ResponseManager.send_resp(conn, 400, nil, error)
    end
  end
end
