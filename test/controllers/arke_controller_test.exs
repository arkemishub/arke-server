defmodule ArkeServer.ArkeControllerTest do
  # TODO: write more specific error case (like params missing or invalid data) and also wirte more create specific case
  use ArkeServer.ConnCase
  alias Arke.UnitManager
  alias Arke.LinkManager

  defp check_arke(_context) do
    ids = [
      :unit_api_ac,
      :group_test_api_arke,
      :test_arke_group_ac,
      :test_unit_arke_ac_1,
      :test_arke_link_ac_1,
      :test_unit_arke_ac_2,
      :test_arke_link_ac_2,
      :link_test_ac,
      :api_string
    ]

    delete_connection("group_test_api_arke", "test_arke_group_ac", "group")
    delete_connection("test_arke_group_ac", "api_string", "parameter")
    delete_connection("test_unit_arke_ac_1", "test_unit_arke_ac_2", "link_test_ac")
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
           |> Arke.QueryManager.filter(:configuration, :eq, metadata, false)
           |> Arke.QueryManager.one() do
      Arke.QueryManager.delete(:test_schema, link)
      :ok
    else
      _ -> :ok
    end
  end



  defp auth_conn(_context) do
    user = get_user()
    %{auth_conn: build_authenticated_conn(user)}
  end

  ################################ ARKE ################################

  describe "get arke struct - GET /lib/:arke_id/struct" do
    test "success" do
      user = get_user()

      conn = build_authenticated_conn(user) |> get("/lib/arke/struct")
      res = json_response(conn, 200)

      assert is_list(res["content"]["parameters"]) == true

      assert is_nil(Enum.find(res["content"]["parameters"], fn param -> param["id"] == "id" end)) ==
               false
    end

    test "error" do
      user = get_user()
      conn = build_authenticated_conn(user) |> get("/lib/error/struct")
      assert conn.status == 404
    end
  end

  ################################ GROUP ################################
  describe "get groups of arke - GET /lib/:arke_id/group" do
    setup [:check_arke, :auth_conn]

    test "success" do
      group_model = ArkeManager.get(:group, :arke_system)

      {:ok, _unit} =
        QueryManager.create(:test_schema, group_model, %{
          id: "group_test_api_arke",
          name: "group_test_api_arke"
        })

      arke_model = ArkeManager.get(:arke, :arke_system)

      {:ok, _unit} =
        QueryManager.create(:test_schema, arke_model, %{
          id: "test_arke_group_ac",
          label: "Test Arke"
        })

      {:ok, _unit} =
        LinkManager.add_node(:test_schema, "group_test_api_arke", "test_arke_group_ac", "group")

      # FIXME: undefined table
      user = get_user()

      conn =
        build_authenticated_conn(user)
        |> get("/lib/test_arke_group_ac/group", %{"limit" => 100, "offset" => 0, "depth" => 1})

      res = json_response(conn, 200)

      assert is_list(res["content"]["parameters"]) == true
    end

    test "error" do
      nil
    end
  end

  ################################ UNIT ################################

  describe "list units - GET /lib/:arke_id/unit" do
    setup [:check_arke, :auth_conn]

    test "success", %{auth_conn: conn} = _context do
      # Create arke
      arke_model = ArkeManager.get(:arke, :arke_system)

      QueryManager.create(:test_schema, arke_model, %{
        id: "test_arke_group_ac",
        label: "Test Arke"
      })

      # Create unit
      arke_model = ArkeManager.get(:test_arke_group_ac, :test_schema)

      QueryManager.create(:test_schema, arke_model, %{
        id: "unit_api_ac",
        label: "Test Unit Api"
      })

      conn = get(conn, "/lib/test_arke_group_ac/unit")
      json_body = json_response(conn, 200)

      assert is_list(json_body["content"]["items"]) == true

      assert is_nil(
               Enum.find(json_body["content"]["items"], fn unit -> unit["id"] == "unit_api_ac" end)
             ) == false
    end

    test "error", %{auth_conn: conn} = _context do
      # FIXME: not existing arke should return 404
      conn = get(conn, "/lib/error/unit")
      assert conn.status == 404
    end
  end

  describe "create unit - POST /lib/:arke_id/unit" do
    setup [:check_arke, :auth_conn]

    test "success", %{auth_conn: conn} = _context do
      # Create arke
      arke_model = ArkeManager.get(:arke, :arke_system)

      QueryManager.create(:test_schema, arke_model, %{
        id: "test_arke_group_ac",
        label: "Test Arke"
      })

      conn =
        post(conn, "/lib/test_arke_group_ac/unit", %{id: "unit_api_post", label: "Test Unit Api"})

      json_body = json_response(conn, 201)

      assert json_body["content"]["id"] == "unit_api_post"
    end

    test "error", %{auth_conn: conn} = _context do
      arke_model = ArkeManager.get(:arke, :arke_system)

      QueryManager.create(:test_schema, arke_model, %{
        id: "test_arke_group_ac",
        label: "Test Arke"
      })

      conn = post(conn, "/lib/test_arke_group_ac/unit", %{})
      json_body = json_response(conn, 400)

      assert Enum.empty?(json_body["messages"]) == false
      assert is_map(List.first(json_body["messages"])) == true
      assert Map.keys(List.first(json_body["messages"])) == ["context", "message"]
    end
  end

  describe "get unit - GET /lib/:arke_id/unit/:unit_id" do
    setup [:check_arke, :auth_conn]

    test "success", %{auth_conn: conn} = _context do
      # Create arke
      arke_model = ArkeManager.get(:arke, :arke_system)

      QueryManager.create(:test_schema, arke_model, %{
        id: "test_arke_group_ac",
        label: "Test Arke"
      })

      # Create unit
      arke_model = ArkeManager.get(:test_arke_group_ac, :test_schema)

      QueryManager.create(:test_schema, arke_model, %{
        id: "unit_api_ac",
        label: "Test Unit Api"
      })

      conn = get(conn, "/lib/test_arke_group_ac/unit/unit_api_ac")
      json_body = json_response(conn, 200)

      assert json_body["content"]["id"] == "unit_api_ac"
    end

    test "error", %{auth_conn: conn} = _context do
      arke_model = ArkeManager.get(:arke, :arke_system)

      QueryManager.create(:test_schema, arke_model, %{
        id: "test_arke_group_ac",
        label: "Test Arke"
      })

      conn = get(conn, "/lib/test_arke_group_ac/unit/error")
      assert conn.status == 404
    end
  end

  describe "update unit data - PUT /lib/:arke_id/unit/:unit_id" do
    setup [:check_arke, :auth_conn]

    test "success", %{auth_conn: conn} = _context do
      # Create arke
      arke_model = ArkeManager.get(:arke, :arke_system)

      QueryManager.create(:test_schema, arke_model, %{
        id: "test_arke_group_ac",
        label: "Test Arke"
      })

      # Create unit
      arke_model = ArkeManager.get(:test_arke_group_ac, :test_schema)

      QueryManager.create(:test_schema, arke_model, %{
        id: "unit_api_ac",
        label: "Test Unit Api"
      })

      conn = put(conn, "/lib/test_arke_group_ac/unit/unit_api_ac", %{label: "label edited"})
      json_body = json_response(conn, 200)

      unit_db = QueryManager.get_by(id: :unit_api_ac, project: :test_schema)

      assert unit_db.data.label == "label edited"
    end

    test "error", %{auth_conn: conn} = _context do
      arke_model = ArkeManager.get(:arke, :arke_system)

      QueryManager.create(:test_schema, arke_model, %{
        id: "test_arke_group_ac",
        label: "Test Arke"
      })

      conn = put(conn, "/lib/test_arke_group_ac/unit/error")
      assert conn.status == 404
    end
  end

  describe "delete unit - DELETE /lib/:arke_id/unit/:unit_id" do
    setup [:check_arke, :auth_conn]

    test "success", %{auth_conn: conn} = _context do
      # Create arke
      arke_model = ArkeManager.get(:arke, :arke_system)

      QueryManager.create(:test_schema, arke_model, %{
        id: "test_arke_group_ac",
        label: "Test Arke"
      })

      # Create unit
      arke_model = ArkeManager.get(:test_arke_group_ac, :test_schema)

      QueryManager.create(:test_schema, arke_model, %{
        id: "unit_api_ac",
        label: "Test Unit Api"
      })

      conn = delete(conn, "/lib/test_arke_group_ac/unit/unit_api_ac")

      assert conn.status == 204
      assert QueryManager.get_by(id: "unit_api_ac", project: :test_schema) == nil
    end
  end

  ################################ TOPOLOGY ################################

  describe "get node - GET /lib/:arke_id/unit/:arke_unit_id/link/:direction" do
    setup [:check_arke, :auth_conn]

    test "success", %{auth_conn: conn} = _context do
      # Create arke
      link_model = ArkeManager.get(:link, :arke_system)

      {:ok, link_unit} =
        QueryManager.create(:test_schema, link_model, %{
          id: "link_test",
          label: "testing",
          name: "testing"
        })

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

      arke_link_model = ArkeManager.get(:arke_link, :arke_system)

      {:ok, link_unit_db} =
        QueryManager.create(:test_schema, arke_link_model,
          parent_id: to_string(unit_1.id),
          child_id: to_string(unit_2.id),
          type: to_string(link_unit.id)
        )

      # FIXME: undefined table
      conn = get(conn, "/lib/test_arke_link_2/unit/test_unit_arke_2/link/parent")
      json_body = json_response(conn, 200)
      IO.inspect(json_body)

      assert is_list(json_body["content"]["items"]) == true

      assert is_nil(
               Enum.find(json_body["content"]["items"], fn unit -> unit["id"] == "unit_api_ac" end)
             ) == false
    end

    test "error", %{auth_conn: conn} = _context do
      conn = get(conn, "/lib/error/unit")
      assert conn.status == 404
    end
  end

  describe "associate link to unit - POST & DELETE /lib/:arke_id/unit/:arke_unit_id/link/:link_id/:arke_id_two/unit/:unit_id_two" do
    setup [:check_arke, :auth_conn]

    test "success", %{auth_conn: conn} = _context do
      post_conn = conn
      del_conn = conn
      # Create arke
      link_model = ArkeManager.get(:link, :arke_system)

      {:ok, link_unit} =
        QueryManager.create(:test_schema, link_model, %{
          id: "link_test_ac",
          label: "testing arke_controller",
          name: "testing arke_controller"
        })

      arke_model = ArkeManager.get(:arke, :arke_system)

      QueryManager.create(:test_schema, arke_model, %{
        id: "test_arke_link_ac_1",
        label: "Test Arke Link 1"
      })

      new_arke_model = ArkeManager.get(:test_arke_link_ac_1, :test_schema)

      {:ok, unit_1} =
        QueryManager.create(:test_schema, new_arke_model, %{
          id: "test_unit_arke_ac_1",
          label: "Test Unit 1"
        })

      QueryManager.create(:test_schema, arke_model, %{
        id: "test_arke_link_ac_2",
        label: "Test Arke Link 2"
      })

      new_arke_model = ArkeManager.get(:test_arke_link_ac_2, :test_schema)

      {:ok, unit_2} =
        QueryManager.create(:test_schema, new_arke_model, %{
          id: "test_unit_arke_ac_2",
          label: "Test Unit 2"
        })

      post_conn =
        post(
          post_conn,
          "/lib/test_arke_link_ac_2/unit/test_unit_arke_ac_1/link/link_test_ac/test_arke_link_ac_2/unit/test_unit_arke_ac_2"
        )

      json_body = json_response(post_conn, 201)
      arke = ArkeManager.get(:test_arke_group_ac, :test_schema)

      assert is_nil(Enum.find(arke.data.parameters, fn p -> p.id == :api_string end)) == false
      assert json_body["content"]["parent_id"] == "test_unit_arke_ac_1"
      assert json_body["content"]["child_id"] == "test_unit_arke_ac_2"
      assert json_body["content"]["type"] == "link_test_ac"

      del_conn =
        delete(
          del_conn,
          "/lib/test_arke_link_ac_2/unit/test_unit_arke_ac_1/link/link_test_ac/test_arke_link_ac_2/unit/test_unit_arke_ac_2"
        )

      arke_del = ArkeManager.get(:test_arke_group_ac, :test_schema)
      assert is_nil(Enum.find(arke_del.data.parameters, fn p -> p.id == :api_string end)) == true
      assert del_conn.status == 204
    end
  end

  ################################ PARAMETER ################################
  describe "associate parameter - POST /lib/:arke_id/parameter/:arke_parameter_id" do
    setup [:check_arke, :auth_conn]

    test "success", %{auth_conn: conn} = _context do
      post_conn = conn
      del_conn = conn
      # Create arke
      parameter_model = ArkeManager.get(:string, :arke_system)

      {:ok, _unit} =
        QueryManager.create(:test_schema, parameter_model, id: :api_string, label: "api string")

      arke_model = ArkeManager.get(:arke, :arke_system)

      {:ok, _unit} =
        QueryManager.create(:test_schema, arke_model, %{
          id: "test_arke_group_ac",
          label: "Test Arke"
        })

      # Create unit
      arke_model = ArkeManager.get(:test_arke_group_ac, :test_schema)

      {:ok, _unit} =
        QueryManager.create(:test_schema, arke_model, %{
          id: "unit_api_ac",
          label: "Test Unit Api"
        })

      post_conn = post(post_conn, "/lib/test_arke_group_ac/parameter/api_string")

      json_body = json_response(post_conn, 201)
      arke = ArkeManager.get(:test_arke_group_ac, :test_schema)

      assert is_nil(Enum.find(arke.data.parameters, fn p -> p.id == :api_string end)) == false
      assert json_body["content"]["parent_id"] == "test_arke_group_ac"
      assert json_body["content"]["child_id"] == "api_string"
      assert json_body["content"]["type"] == "parameter"

      del_conn =
        delete(
          del_conn,
          "/lib/arke/unit/test_arke_group_ac/link/parameter/string/unit/api_string"
        )

      arke_del = ArkeManager.get(:test_arke_group_ac, :test_schema)
      assert is_nil(Enum.find(arke_del.data.parameters, fn p -> p.id == :api_string end)) == true
      assert del_conn.status == 204
    end

    test "error" do
      nil
    end
  end
end
