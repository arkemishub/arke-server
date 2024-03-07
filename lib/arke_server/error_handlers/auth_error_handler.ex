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

########################################################################
### STANDARD AUTH ERROR HANDLER ########################################
########################################################################
defmodule ArkeServer.ErrorHandlers.Auth do
  @moduledoc """
             """ && false

  alias Arke.Utils.ErrorGenerator, as: Error
  import Plug.Conn

  @behaviour ArkeAuth.Guardian.Plug.ErrorHandler
  @impl ArkeAuth.Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, reason}, opts) do
    {:error, msg} = get_message(type, conn.req_headers)
    ArkeServer.ResponseManager.send_resp(conn, 401, nil, msg)
  end

  defp get_message(kwd, headers) do
    with [_] <- Enum.filter(headers, fn {k, v} -> k == "authorization" end) do
      Error.create(:auth, Atom.to_string(kwd))
    else
      _ -> Error.create(:auth, "missing authorization header")
    end
  end
end
########################################################################
### SSO AUTH PIPELINE ##################################################
########################################################################
defmodule ArkeServer.ErrorHandlers.SSOAuth do
  @moduledoc """
             """ && false

  alias Arke.Utils.ErrorGenerator, as: Error
  import Plug.Conn

  @behaviour ArkeAuth.SSOGuardian.Plug.ErrorHandler
  @impl ArkeAuth.SSOGuardian.Plug.ErrorHandler
  def auth_error(conn, {type, reason}, opts) do
    {:error, msg} = get_message(type, conn.req_headers)
    ArkeServer.ResponseManager.send_resp(conn, 401, nil, msg)
  end

  defp get_message(kwd, headers) do
    with [_] <- Enum.filter(headers, fn {k, v} -> k == "authorization" end) do
      Error.create(:auth, Atom.to_string(kwd))
    else
      _ -> Error.create(:auth, "missing authorization header")
    end
  end
end