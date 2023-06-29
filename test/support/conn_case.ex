defmodule ArkeServer.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use ArkeServer.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias ArkeServer.Router.Helpers, as: Routes
      # The default endpoint for testing
      @endpoint ArkeServer.Endpoint
      alias ArkeAuth.Guardian
      alias ArkePostgres.Repo
      alias Arke.Boundary.{ArkeManager, ParameterManager, ParamsManager, GroupManager}
      alias Arke.QueryManager

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import ArkeServer.ConnCase

      def build_authenticated_conn(user \\ get_user()) do
        {:ok, token, _} = Guardian.encode_and_sign(user)

        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
        |> Plug.Conn.put_req_header("arke-project-key", "test_schema")
      end

      defp get_user_params(username \\ "user_test"),
        do: [
          username: username,
          password: "password",
          type: "customer",
          first_name: "Test",
          last_name: "User"
        ]

      def get_user(username \\ "user_test") do
        user = QueryManager.get_by(username: username, project: :arke_system)

        with nil <- user do
          user_model = ArkeManager.get(:user, :arke_system)

          {:ok, new_user} =
            QueryManager.create(:arke_system, user_model, get_user_params(username))

          new_user
        else
          _ -> user
        end
      end

      def delete_user(username \\ "user_test") do
        with nil <- Arke.QueryManager.get_by(username: username, project: :arke_system) do
          nil
        else
          _ ->
            Arke.QueryManager.delete(
              :arke_system,
              Arke.QueryManager.get_by(username: username, project: :arke_system)
            )
        end
      end

      def check_db(id) do
        with nil <-
               Arke.QueryManager.get_by(id: id, project: :test_schema) do
          :ok
        else
          _ ->
            Arke.QueryManager.delete(
              :test_schema,
              Arke.QueryManager.get_by(id: id, project: :test_schema)
            )

            :ok
        end
      end
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ArkePostgres.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(ArkePostgres.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
