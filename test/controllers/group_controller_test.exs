defmodule ArkeServer.GroupControllerTest do
  use ArkeServer.ConnCase
  alias Arke.LinkManager

  defp check_arke(_context) do
    ids = [:test_api_unit, :group_test_api, :test_arke_group_gc]
    delete_connection("group_test_api", "test_arke_group_gc", "group")
    Enum.each(ids, fn id -> check_db(id) end)
    :ok
  end

  defp delete_connection(parent, child, type, metadata \\ %{}) do
    arke_link = ArkeManager.get(:arke_link, :arke_system)

    with %Arke.Core.Unit{} = link <-
           Arke.QueryManager.query(project: :test_schema, arke: arke_link)
           |> Arke.QueryManager.filter(:parent_id, :eq, parent, false)
           |> Arke.QueryManager.filter(:child_id, :eq, child, false)
           |> Arke.QueryManager.filter(:type, :eq, type, false)
           |> Arke.QueryManager.filter(:metadata, :eq, metadata, false)
           |> Arke.QueryManager.one() do
      Arke.QueryManager.delete(:test_schema, link)
      :ok
    else
      _ -> :ok
    end
  end

  ###############################

  defp associate_arke(_context) do
    arke_model = ArkeManager.get(:arke, :arke_system)

    QueryManager.create(:test_schema, arke_model, %{id: "test_arke_group_gc", label: "Test Arke"})

    arke_api = ArkeManager.get(:test_arke_group_gc, :test_schema)
    QueryManager.create(:test_schema, arke_api, %{id: :test_api_unit, label: "Test Arke Unit"})

    group_model = ArkeManager.get(:group, :arke_system)

    QueryManager.create(:test_schema, group_model, %{id: "group_test_api", name: "group_test_api"})

    LinkManager.add_node(:test_schema, "group_test_api", "test_arke_group_gc", "group")
    :ok
  end

  describe "/lib/group/:group_id/arke" do
    setup [:check_arke, :associate_arke]

    test "get_arke - GET" do
      user = get_user()

      conn =
        build_authenticated_conn(user)
        |> get("/lib/group/group_test_api/arke")

      body_resp = json_response(conn, 200)

      assert List.first(body_resp["content"]["items"])["id"] == "test_arke_group_gc"
      assert List.first(body_resp["content"]["items"])["type"] == "arke"
    end

    test "get_arke - GET (error)" do
      # atom below only to prevent error: not an already existing atom
      :invalid_group

      user = get_user()

      conn =
        build_authenticated_conn(user)
        |> get("/lib/group/invalid_group/arke")

      assert conn.status == 404
    end
  end

  describe "/lib/group/:group_id/struct" do
    setup [:check_arke, :associate_arke]

    test "struct - GET" do
      user = get_user()

      conn =
        build_authenticated_conn(user)
        |> get("/lib/group/parameter/struct")

      body_resp = json_response(conn, 200)

      assert body_resp["content"]["label"] == "Parameter"
      assert is_list(body_resp["content"]["parameters"]) == true
      assert length(body_resp["content"]["parameters"]) > 0
    end
  end

  describe "/lib/group/:group_id/unit" do
    setup [:check_arke, :associate_arke]

    test "get_unit - GET" do
      user = get_user()

      conn =
        build_authenticated_conn(user)
        |> get("/lib/group/group_test_api/unit")

      body_resp = json_response(conn, 200)

      assert body_resp["content"]["count"] > 0
      assert is_list(body_resp["content"]["items"]) == true
      assert List.first(body_resp["content"]["items"])["id"] == "test_api_unit"
    end
  end

  describe "/lib/group/:group_id/unit/:unit_id" do
    setup [:check_arke, :associate_arke]

    test "unit_detail - GET" do
      user = get_user()

      conn =
        build_authenticated_conn(user)
        |> get("/lib/group/group_test_api/unit/test_api_unit")

      body_resp = json_response(conn, 200)

      assert body_resp["content"]["arke_id"] == "test_arke_group_gc"
      assert body_resp["content"]["id"] == "test_api_unit"
    end
  end
end
