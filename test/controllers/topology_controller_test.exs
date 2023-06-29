defmodule ArkeServer.TopologyControllerTest do
  use ArkeServer.ConnCase

  defp create_link(conn) do
    post(
      conn,
      "/lib/test_arke_link_1/unit/test_unit_arke_1/link/child/test_arke_link_2/unit/test_unit_arke_2",
      %{}
    )
  end

  defp create_units(_) do
    arke_model = ArkeManager.get(:arke, :arke_system)

    QueryManager.create(:test_schema, arke_model, %{
      id: "test_arke_link_1",
      label: "Test Arke Link 1"
    })

    new_arke_model = ArkeManager.get(:test_arke_link_1, :test_schema)

    {:ok, unit_1} =
      QueryManager.create(:test_schema, new_arke_model, %{
        id: "test_unit_arke_1",
        label: "Test Unit 1"
      })

    QueryManager.create(:test_schema, arke_model, %{
      id: "test_arke_link_2",
      label: "Test Arke Link 2"
    })

    new_arke_model = ArkeManager.get(:test_arke_link_2, :test_schema)

    {:ok, unit_2} =
      QueryManager.create(:test_schema, new_arke_model, %{
        id: "test_unit_arke_2",
        label: "Test Unit 2"
      })

    {:ok, unit_1: unit_1, unit_2: unit_2}
  end

  defp auth_conn(_context) do
    user = get_user()
    %{auth_conn: build_authenticated_conn(user)}
  end

  describe "create node" do
    setup([:auth_conn, :create_units])

    test "success", %{auth_conn: conn} do
      conn =
        post(
          conn,
          "/lib/test_arke_link_1/unit/test_unit_arke_1/link/child/test_arke_link_2/unit/test_unit_arke_2",
          %{}
        )

      json_body = json_response(conn, 201)

      assert json_body["content"]["parent_id"] == "test_unit_arke_1"
      assert json_body["content"]["child_id"] == "test_unit_arke_2"
      assert json_body["content"]["arke_id"] == "arke_link"
    end

    test "error", %{auth_conn: conn} do
      create_link(conn)

      conn =
        post(
          conn,
          "/lib/test_arke_link_1/unit/test_unit_arke_1/link/child/test_arke_link_2/unit/test_unit_arke_2",
          %{}
        )

      assert conn.status == 400
    end
  end

  describe "delete node" do
    setup([:auth_conn, :create_units])

    test "success", %{auth_conn: conn} do
      create_link(conn)

      conn =
        delete(
          conn,
          "/lib/test_arke_link_1/unit/test_unit_arke_1/link/child/test_arke_link_2/unit/test_unit_arke_2",
          %{}
        )

      assert conn.status == 204
    end

    test "error", %{auth_conn: conn} do
      conn =
        delete(
          conn,
          "/lib/test_arke_link_1/unit/test_unit_arke_1/link/child/test_arke_link_2/unit/test_unit_arke_2",
          %{}
        )

      assert conn.status == 404
    end
  end

  describe "get_node" do
    setup([:auth_conn, :create_units])

    test "success", %{auth_conn: conn} do
      create_link(conn)

      conn =
        get(
          conn,
          "/lib/test_arke_link_1/unit/test_unit_arke_1/link/child"
        )

      json_body = json_response(conn, 200)

      assert List.first(json_body["content"]["items"])["id"] == "test_unit_arke_2"
    end
  end
end
