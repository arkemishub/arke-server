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

defmodule ArkeServer.ErrorView do
  @moduledoc """
             Documentation for `ArkeServer.ErrorView`
             """
  use ArkeServer, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Internal Server Error"}}
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".

  defmacro __using__(_)do
    quote do
      require Logger

      alias Arke.Errors.ArkeError
      alias Arke.Utils.ErrorGenerator

      # TO CATCH SPECIFIC ERROR STATUS
#      def render("422.json", assigns) do
#         handle_error(assigns)
#      end
      def render(any_status, assigns) do
        {:error, err} = handle_error(assigns)
        err
      end

      def template_not_found(template, _assigns) do
        {:error, err} = ErrorGenerator.create(:generic, "template not found")
        err
      end

      def handle_error(%{reason: %ArkeError{:context => context, :errors => errors, :plug_status => status} = arke_error} = assigns) do
        log_error_message(assigns, arke_error)
        ErrorGenerator.create(context, errors)
      end
      def handle_error(assigns) do
        log_error_message(assigns)
        ErrorGenerator.create(:generic, assigns.reason)
      end

      defp log_error_message(assigns, %ArkeError{:context => context, :plug_status => status}) do
        context = "\t ########  Error #{status} in #{to_string(context)}  ########\n"
        log_error_message(assigns, context)
      end
      defp log_error_message(assigns, context \\ "") do
        [{first_module_of_stack, _, _, _} | _] = assigns.stack
        message = "running #{first_module_of_stack} terminated\n"
        message = message <> context
        message = message <> Enum.reduce(assigns.stack, "", fn {module, function, fun_param, info}, acc ->
#          file = Keyword.get(info, :file) #Used to take path of file in error
          line = Keyword.get(info, :line)
          "#{to_string(acc)}\t(#{to_string(module)}) #{to_string(function)}/#{to_string(fun_param)} line: #{to_string(line)}\n"
          # OTHER WAY TO LOG WITH FILE SPECIFICATION
#          "#{to_string(acc)}\t(#{to_string(module)}) #{to_string(function)}/#{to_string(fun_param)} \n\t\t #{file}: line: #{to_string(line)}\n"
        end)
        Logger.error(message)
      end
    end
  end


end
