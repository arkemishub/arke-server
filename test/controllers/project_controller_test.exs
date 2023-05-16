defmodule ArkeServer.ProjectControllerTest do
  use ArkeServer.ConnCase

  def delete_project() do
    proj = Arke.QueryManager.get_by(id: :test_api_schema, project: :arke_system)

    with nil <- proj do
      nil
    else
      _ -> Arke.QueryManager.delete(:arke_system, proj)
    end
  end

  describe "/arke_project/unit/" do
    test "create - POST" do
      user = get_user()

      project_params = %{
        id: "test_api_schema",
        name: "test_api_schema",
        description: "test api schema",
        type: "postgres_schema",
        label: "Test API Project"
      }

      conn =
        build_authenticated_conn(user)
        |> post("/lib/arke_project/unit", project_params)

      body_resp = json_response(conn, 200)

      assert body_resp["content"]["id"] == "test_api_schema"
      assert body_resp["content"]["arke_id"] == "arke_project"

      db_project =
        QueryManager.get_by(id: "test_api_schema", project: "arke_system", arke_id: :arke_project)

      assert db_project != nil
      assert db_project.id == :test_api_schema

      delete_project()
    end

    test "index - GET" do
      user = get_user()

      conn =
        build_authenticated_conn(user)
        |> get("/lib/arke_project/unit")

      body_resp = json_response(conn, 200)

      assert body_resp["content"]["count"] > 0

      assert length([
               Enum.find(body_resp["content"]["items"], fn item -> item["id"] == "test_schema" end)
             ]) > 0
    end
  end

  describe "/arke_project/unit/:unit_id" do
    test "show - GET" do
      user = get_user()

      conn =
        build_authenticated_conn(user)
        |> get("/lib/arke_project/unit/test_schema")

      body_resp = json_response(conn, 200)

      assert body_resp["content"]["arke_id"] == "arke_project"
      assert body_resp["content"]["id"] == "test_schema"
    end

    test "update - PUT" do
      # CREATE
      user = get_user()

      project_params = %{
        id: "test_api_schema",
        name: "test_api_schema",
        description: "test api schema",
        type: "postgres_schema",
        label: "Test API Project"
      }

      conn =
        build_authenticated_conn(user)
        |> post("/lib/arke_project/unit", project_params)

      body_resp = json_response(conn, 200)

      db_project =
        QueryManager.get_by(id: "test_api_schema", project: "arke_system", arke_id: :arke_project)

      # UPDATE
      project_params_update = %{
        description: "test api schema edited",
        label: "Test API Project edited"
      }

      conn =
        build_authenticated_conn(user)
        |> put("/lib/arke_project/unit/#{db_project.id}", project_params_update)

      db_project_updated =
        QueryManager.get_by(id: :test_api_schema, project: :arke_system, arke_id: :arke_project)

      updated_body_resp = json_response(conn, 200)

      assert body_resp["content"]["label"] != updated_body_resp["content"]["label"]
      assert updated_body_resp["content"]["label"] == "Test API Project edited"

      assert db_project_updated.id == db_project.id
      assert db_project_updated.data.label != db_project.data.label
      assert db_project.data.label == "Test API Project"
      assert db_project_updated.data.label == "Test API Project edited"

      delete_project()
    end

    test "delete - DELETE" do
      # CREATE
      user = get_user()

      project_params = %{
        id: "test_api_schema",
        name: "test_api_schema",
        description: "test api schema",
        type: "postgres_schema",
        label: "Test API Project"
      }

      conn =
        build_authenticated_conn(user)
        |> post("/lib/arke_project/unit", project_params)

      body_resp = json_response(conn, 200)

      db_project =
        QueryManager.get_by(id: "test_api_schema", project: "arke_system", arke_id: :arke_project)

      # DELETE
      conn =
        build_authenticated_conn(user)
        |> delete("/lib/arke_project/unit/#{db_project.id}")

      db_project_updated =
        QueryManager.get_by(id: :test_api_schema, project: :arke_system, arke_id: :arke_project)

      assert conn.status == 204
      assert db_project_updated == nil
    end
  end
end
