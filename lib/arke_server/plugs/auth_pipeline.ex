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
### STANDARD AUTH PIPELINE #############################################
########################################################################
defmodule ArkeServer.Plugs.AuthPipeline do
  @moduledoc """
  Pipeline To ensure that the user is always authenticated and authorized
  """

  use Guardian.Plug.Pipeline,
    otp_app: :arke_auth,
    module: ArkeAuth.Guardian,
    error_handler: ArkeServer.ErrorHandlers.Auth

  plug(Guardian.Plug.VerifyHeader, scheme: "Bearer")
  plug(Guardian.Plug.EnsureAuthenticated)
  plug(Guardian.Plug.LoadResource)
end

defmodule ArkeServer.Plugs.ImpersonateAuthPipeline do
  @moduledoc """
  Pipeline to ensure authentication of user and impersonate user
  """

  use Guardian.Plug.Pipeline,
    otp_app: :arke_auth,
    module: ArkeAuth.Guardian,
    error_handler: ArkeServer.ErrorHandlers.Auth

  plug(Guardian.Plug.VerifyHeader, scheme: "Bearer")
  plug(Guardian.Plug.EnsureAuthenticated)
  plug(Guardian.Plug.LoadResource)

  plug(Guardian.Plug.VerifyHeader,
    scheme: "Bearer",
    header_name: "impersonate-token",
    key: "impersonate"
  )

  plug(Guardian.Plug.EnsureAuthenticated, key: :impersonate)
  plug(Guardian.Plug.LoadResource, key: :impersonate)
end

defmodule ArkeServer.Plugs.NotAuthPipeline do
  @moduledoc """
  Pipeline for all the non-authorized endpoints
  """
  use Guardian.Plug.Pipeline,
    otp_app: :arke_auth,
    module: ArkeAuth.Guardian,
    error_handler: ArkeServer.ErrorHandlers.Auth

  plug(Guardian.Plug.EnsureNotAuthenticated)
end

########################################################################
### SSO AUTH PIPELINE ##################################################
########################################################################
defmodule ArkeServer.Plugs.SSOAuthPipeline do
  @moduledoc """
  Pipeline to ensure the existence of an arke user from a sso jwt token
  """

  use Guardian.Plug.Pipeline,
    otp_app: :arke_auth,
    module: ArkeAuth.SSOGuardian,
    error_handler: ArkeServer.ErrorHandlers.SSOAuth

  plug(Guardian.Plug.VerifyHeader, scheme: "Bearer")
  plug(Guardian.Plug.EnsureAuthenticated)
  plug(Guardian.Plug.LoadResource)
end

defmodule ArkeServer.Plugs.SSONotAuthPipeline do
  @moduledoc """
  Pipeline for all the non-authorized endpoints
  """
  use Guardian.Plug.Pipeline,
    otp_app: :arke_auth,
    module: ArkeAuth.SSOGuardian,
    error_handler: ArkeServer.ErrorHandlers.SSOAuth

  plug(Guardian.Plug.EnsureNotAuthenticated)
end
