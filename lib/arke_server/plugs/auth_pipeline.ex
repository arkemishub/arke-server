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

defmodule ArkeServer.Plugs.AuthPipeline do
  @moduledoc """
             Pipeline To ensure that the user is always authenticated and authorized
             """ && false

  use Guardian.Plug.Pipeline,
    otp_app: :arke_auth,
    module: ArkeAuth.Guardian,
    error_handler: ArkeServer.ErrorHandlers.Auth

  plug(Guardian.Plug.VerifyHeader, scheme: "Bearer")
#  plug(Guardian.Plug.EnsureAuthenticated)
  plug(Guardian.Plug.LoadResource, allow_blank: true)
end

defmodule ArkeServer.Plugs.NotAuthPipeline do
  @moduledoc """
             Pipeline for all the non-authorized endpoints
             """ && false
  use Guardian.Plug.Pipeline,
    otp_app: :arke_auth,
    module: ArkeAuth.Guardian,
    error_handler: ArkeServer.ErrorHandlers.Auth

  plug(Guardian.Plug.EnsureNotAuthenticated)
end
