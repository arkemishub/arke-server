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

  ######################################################################
  #### START --- CREATE PATH FOR CUSTOM FUNCTIONS IN ARKE AND GROUP ####
  ######################################################################

  def custom_function_endpoint() do
    swagger_module_prefix = Application.get_env(:arke_server, :openapi_module, nil)

    if is_nil(swagger_module_prefix) do
      []
    else
      {:ok, modules} = :application.get_key(Mix.Project.config()[:app], :modules)

      modules
      |> Enum.filter(
        &(function_exported?(&1, :is_arke?, 0) or function_exported?(&1, :is_group?, 0))
      )
      |> Enum.flat_map(&extract_custom_functions(&1, swagger_module_prefix))
      |> Enum.reduce(%{}, &build_function_map(&1, &2))
    end
  end

  defp extract_custom_functions(module, swagger_module_prefix) do
    system_functions =
      Arke.System.Arke.__info__(:functions) ++ Arke.System.BaseGroup.__info__(:functions)

    custom_functions = module.__info__(:functions) -- system_functions

    Enum.map(custom_functions, fn function ->
      {get_swagger_module(swagger_module_prefix, module), function}
    end)
  end

  defp build_function_map({swagger_module, {fun, arity}}, acc) do
    IO.inspect(fun, label: swagger_module)

    if Code.ensure_loaded?(swagger_module) and function_exported?(swagger_module, fun, 0) do
      unit_path = get_unit_path(arity)
      arke_id = Module.split(swagger_module) |> List.last() |> pascal_to_snake()

      Map.put(
        acc,
        to_string("/lib/#{arke_id}#{unit_path}/function/#{fun}"),
        apply(swagger_module, fun, [])
      )
    else
      acc
    end
  end

  def pascal_to_snake(pascal) do
    pascal
    |> String.replace(~r/([a-z])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end

  defp get_swagger_module(swagger_module_prefix, module) do
    Module.concat(swagger_module_prefix, Module.split(module) |> List.last())
  end

  defp get_unit_path(1), do: "/unit/{unit_id}"
  defp get_unit_path(_), do: ""

  ####################################################################
  #### END --- CREATE PATH FOR CUSTOM FUNCTIONS IN ARKE AND GROUP ####
  ####################################################################

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
