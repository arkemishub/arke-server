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

defmodule ArkeServer.Openapi.Spec do
  @doc """
  For each controller define the module containing its apispec definitions.
  In your controller module:
      use ArkeServer.Openapi.Spec, module: My.Spec.Module
  """
  defmacro __using__(opts) do
    apimodule = Keyword.get(opts, :module, nil)

    quote do
      alias Arke.Boundary.ArkeManager
      alias ArkeServer.Openapi.Responses
      alias OpenApiSpex.{Operation, Reference}

      def open_api_operation(action) do
        apimodule = unquote(apimodule)

        unless is_nil(apimodule) do
          func_list = get_operation_list(apimodule)
          operation = "#{action}_operation"

          if operation in func_list do
            apply(apimodule, String.to_existing_atom(operation), [])
          end
        end
      end

      defp get_operation_list(nil), do: []

      defp get_operation_list(module) do
        module.__info__(:functions)
        |> Enum.map(fn {func_name, _arity} -> to_string(func_name) end)
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
    end
  end
end
