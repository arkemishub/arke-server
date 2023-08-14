defmodule ArkeServer.OAuth.AuthInfo do
  alias ArkeServer.OAuth.UserInfo

  defstruct uid: nil,
            provider: nil,
            strategy: nil,
            info: %UserInfo{}
end
