defmodule ArkeServer.ApiSpec do
  alias OpenApiSpex.{
    Components,
    Info,
    OpenApi,
    Paths,
    SecurityScheme,
    Parameter,
    Schema,
    Server
  }

  alias ArkeServer.{Endpoint, Router}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: get_servers(Application.get_env(:arke_server, :endpoint_module)),
      info: %Info{
        title: "Arke Api",
        version: Mix.Project.config()[:version]
      },
      components: %Components{
        securitySchemes: %{
          "authorization" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            description:
              "API Token must follow: `Bearer {access_token}` Use the signin endpoint to get the token value"
          }
        },
        parameters: get_parameters()
      },
      # Populate the paths from a phoenix router
      paths: Map.merge(custom_function_endpoint(), Paths.from_router(Router))
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  ################################################################

  alias Arke.Boundary.ArkeManager

  def custom_function_endpoint() do
    ArkeManager.get_all(:cx_tool)
    |> Enum.map(fn {k, v} -> Map.get(ArkeManager.get(k, :cx_tool), :__module__) end)
    |> Enum.filter(fn module -> not library_module?(module) end)
    |> Enum.reduce([], fn project_module, acc ->
      custom_functions =
        project_module.__info__(:functions) -- Arke.System.Arke.__info__(:functions)

      Enum.map(custom_functions, &{get_operation_module(project_module), &1}) ++ acc
    end)
    |> Enum.reduce(%{}, fn {operation_module, {fun, arity}}, acc ->
      fun_operation = :"#{fun}_operation"

      if Code.ensure_loaded?(operation_module) and
           function_exported?(operation_module, fun_operation, 0) do
        unit_path = if arity == 1, do: "", else: "/unit/{unit_id}"
        arke_id = Module.split(operation_module) |> List.last() |> pascal_to_snake()

        Map.put(
          acc,
          to_string("lib/#{arke_id}#{unit_path}/function/#{fun}"),
          get_schema(apply(operation_module, fun_operation, []))
        )
      else
        acc
      end
    end)
  end

  def pascal_to_snake(pascal) do
    pascal
    |> String.replace(~r/([a-z])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end

  defp library_module?(module) do
    library_modules = ["Arke", "ArkeAuth", "ArkeServer", "ArkePostgres"]
    String.starts_with?(to_string(module), Enum.map(library_modules, &"Elixir.#{&1}."))
  end

  defp get_operation_module(module) do
    new_splitted_module =
      Module.split(module)
      |> Enum.map(&get_module_part(&1))

    Module.concat(new_splitted_module)
  end

  defp get_module_part("Arke"), do: "Operation"
  defp get_module_part(v), do: v

  def get_schema(operation) do
    %OpenApiSpex.PathItem{
      get: operation,
      post: operation
    }
  end

  ################################################################

  defp get_parameters() do
    %{
      "arke-project-key" => %Parameter{
        name: "arke-project-key",
        in: :header,
        required: true,
        description: "Key which define the project where to use the API",
        schema: %Schema{
          type: :string
        }
      },
      "unit_id" => %Parameter{
        name: "unit_id",
        in: :path,
        required: true,
        description: "Unit ID",
        schema: %Schema{
          type: :string
        }
      },
      "group_id" => %Parameter{
        name: "group_id",
        in: :path,
        required: true,
        description: "Group ID",
        schema: %Schema{
          type: :string
        }
      },
      "link_id" => %Parameter{
        name: "link_id",
        in: :path,
        required: true,
        description: "Link ID",
        schema: %Schema{
          type: :string
        }
      },
      "arke_parameter_id" => %Parameter{
        name: "arke_parameter_id",
        in: :path,
        required: true,
        description: "Id of the parameter to link",
        schema: %Schema{
          type: :string
        }
      },
      "arke_id" => %Parameter{
        name: "arke_id",
        in: :path,
        required: true,
        description: "Arke ID",
        schema: %Schema{type: :string}
      },
      "limit" => %Parameter{
        name: "limit",
        in: :query,
        required: false,
        description: "Limits the number of returned results",
        schema: %Schema{
          type: :integer,
          minimum: 0
        }
      },
      "offset" => %Parameter{
        name: "offset",
        in: :query,
        required: false,
        description: "Set an offset",
        schema: %Schema{
          type: :integer,
          minimum: 0
        }
      },
      "order" => %Parameter{
        name: "order[]",
        in: :query,
        required: false,
        description: "Define in which order get the returned results",
        schema: %Schema{
          type: :string,
          example: "order[]=id;desc&order[]=label;asc"
        }
      },
      "filter" => %Parameter{
        name: "filter",
        in: :query,
        required: false,
        description: "Arke API filter",
        schema: %Schema{
          type: :string,
          example: "filter=and(gte(age,23),contains(name,string))"
        }
      },
      "provider" => %Parameter{
        name: "provider",
        in: :path,
        required: true,
        description: "Oauth provider",
        schema: %Schema{
          type: :string,
          example: "google"
        }
      }
    }
  end

  defp get_servers(nil) do
    [%Server{url: "http://localhost:4000"}]
  end

  defp get_servers(endpoint_module) when is_list(endpoint_module),
    do: create_server_list(endpoint_module)

  defp get_servers(endpoint_module), do: create_server_list([endpoint_module])

  defp create_server_list(module_list) do
    server_list = Enum.into(module_list, [], fn m -> get_uri(m) end)
    server_list = Enum.filter(server_list, fn s -> !is_nil(s) end)

    case length(server_list) do
      0 -> get_servers(nil)
      _ -> server_list
    end
  end

  defp get_uri(module) do
    with true <- Kernel.function_exported?(module, :struct_url, 0),
         true <- Kernel.function_exported?(module, :path, 1) do
      url = module.struct_url()
      path = module.path("") || "/"
      uri = %{url | path: path}
      %Server{url: URI.to_string(uri)}
    else
      _ -> nil
    end
  end
end
