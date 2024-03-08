defmodule ArkeServer.Openapi.TopologyControllerSpec do
  @moduledoc """
  Definition of the ApiSpec for `ArkeServer.TopologyController`.
  """

  alias ArkeServer.Openapi.Responses
  alias OpenApiSpex.{Operation, Reference}

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

  def update_node_operation() do
    %Operation{
      tags: ["Topology"],
      summary: "Update connection",
      description: "Update link metadata between two units",
      operationId: "ArkeServer.TopologyController.update_node(",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
        Operation.parameter(:arke_unit_id, :path, :string, "Parent Unit ID", required: true),
        %Reference{"$ref": "#/components/parameters/link_id"},
        Operation.parameter(:arke_id_two, :path, :string, "Child Arke ID", required: true),
        Operation.parameter(:unit_id_two, :path, :string, "Child Arke ID", required: true),
        %Reference{"$ref": "#/components/parameters/arke-project-key"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([200])
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

  def update_parameter_operation() do
    %Operation{
      tags: ["Parameter"],
      summary: "Update associated parameter",
      description: "Updates associated parameter of the given Arke",
      operationId: "ArkeServer.TopologyController.update_parameter",
      parameters: [
        %Reference{"$ref": "#/components/parameters/arke_id"},
        %Reference{"$ref": "#/components/parameters/arke_parameter_id"},
        %Reference{"$ref": "#/components/parameters/arke-project-key"}
      ],
      security: [%{"authorization" => []}],
      responses: Responses.get_responses([200])
    }
  end

end
