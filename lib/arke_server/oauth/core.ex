defmodule ArkeServer.OAuth.Core do
  alias ArkeServer.OAuth.AuthInfo

  defmacro __using__(opts \\ []) do
    quote do
      import Plug.Conn, except: [request_url: 1]

      alias Arke.Utils.ErrorGenerator, as: Error
      alias ArkeServer.OAuth.UserInfo, as: UserInfo
      def default_options, do: unquote(opts)

      def info(conn), do: %UserInfo{}
      def uid(conn), do: nil

      def handle_request(conn), do: conn

      def handle_cleanup(conn), do: conn

      defoverridable info: 1,
                     uid: 1,
                     handle_request: 1,
                     handle_cleanup: 1
    end
  end

  def run_request(conn, strategy) do
    apply(strategy, :handle_request, [conn])
    |> handle_result(strategy)
    |> run_handle_cleanup(strategy)
  end

  defp run_handle_cleanup(conn, strategy) do
    apply(strategy, :handle_cleanup, [conn])
  end

  defp handle_result(%{halted: true} = conn, _), do: conn
  defp handle_result(%{assigns: %{arke_server_oauth_failure: _}} = conn, _), do: conn
  defp handle_result(%{assigns: %{arke_server_oauth: %{}}} = conn, _), do: conn

  defp handle_result(conn, strategy) do
    Plug.Conn.assign(conn, :arke_server_oauth, auth(conn, strategy))
  end

  defp auth(conn, strategy) do
    %AuthInfo{
      provider: conn.private[:arke_server_request_options][:strategy_name] || nil,
      strategy: strategy,
      uid: strategy.uid(conn),
      info: strategy.info(conn)
    }
  end
end
