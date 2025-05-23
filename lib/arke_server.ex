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

defmodule ArkeServer do
  @moduledoc """
             The entrypoint for defining your web interface, such
             as controllers, views, channels and so on.

             This can be used in your application as:

                 use ArkeServer, :controller
                 use ArkeServer, :view

             The definitions below will be executed for every view,
             controller, etc, so keep them short and clean, focused
             on imports, uses and aliases.

             Do NOT define functions inside the quoted expressions
             below. Instead, define any helper function in modules
             and import those modules here.
             """

  def controller do
    quote do
      use Phoenix.Controller, namespace: ArkeServer

      import Plug.Conn
      alias ArkeServer.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/arke_server/templates",
        namespace: ArkeServer

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  defp view_helpers do
    quote do
      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import ArkeServer.ErrorHelpers
      alias ArkeServer.Router.Helpers, as: Routes
    end
  end

  defimpl Plug.Exception, for: Arke.Errors.ArkeError do
    def status(%Arke.Errors.ArkeError{type: :unauthorized}), do: 401
    def status(%Arke.Errors.ArkeError{type: :forbidden}), do: 403
    def status(%Arke.Errors.ArkeError{type: :not_found}), do: 404
    def status(%Arke.Errors.ArkeError{type: _type}), do: 400

    def actions(_exception), do: []  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
