defmodule ArkeServer.AuthControllerTest do
  use ArkeServer.ConnCase

  def create_user_setup(context) do
    get_user("user2")
    context
  end

  describe "POST /lib/auth/signin" do
    setup [:create_user_setup]

    test "success", %{conn: conn} do
      conn = post(conn, "/lib/auth/signin", username: "user2", password: "password")
      assert conn.status == 200
      delete_user("user2")
    end

    test "error", %{conn: conn} do
      conn = post(conn, "/lib/auth/signin", username: "user2")
      assert conn.status == 404
      delete_user("user2")
    end
  end

  test "POST /lib/auth/signup", %{conn: conn} do
    conn =
      post(conn, "/lib/auth/signup", username: "user3", password: "password", type: "customer")

    body_resp = json_response(conn, 201)
    assert body_resp["content"]["username"] == "user3"

    delete_user("user2")
  end

  test "POST /lib/auth/refresh", %{conn: conn} do
    create_user_setup(nil)
    # Get tokens
    get_token_conn = post(conn, "/lib/auth/signin", username: "user2", password: "password")
    signin_body_resp = json_response(get_token_conn, 200)
    old_access_token = signin_body_resp["content"]["access_token"]
    old_refresh_token = signin_body_resp["content"]["refresh_token"]

    conn =
      build_conn()
      |> Plug.Conn.put_req_header("authorization", "Bearer #{old_refresh_token}")
      |> Plug.Conn.put_req_header("arke-project-key", "test_schema")

    conn = post(conn, "/lib/auth/refresh")
    body_resp = json_response(conn, 200)
    new_access_token = body_resp["content"]["access_token"]
    new_refresh_token = body_resp["content"]["refresh_token"]

    assert new_access_token != old_access_token and new_refresh_token != old_refresh_token
    delete_user("user2")
  end

  describe "POST /lib/auth/verify" do
    setup [:create_user_setup]

    test "success" do
      user = Arke.QueryManager.get_by(project: :arke_system, username: "user2")

      conn =
        build_authenticated_conn(user)
        |> post("/lib/auth/verify")

      assert conn.status == 200
      delete_user("user2")
    end

    test "error invalid token" do
      conn =
        build_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer INVALID TOKEN")
        |> post("/lib/auth/verify")
        |> json_response(401)

      assert List.first(conn["messages"])["message"] == "invalid_token"
      delete_user("user2")
    end

    test "error missing auth header" do
      conn =
        build_conn()
        |> post("/lib/auth/verify")
        |> json_response(401)

      assert List.first(conn["messages"])["message"] == "missing authorization header"
      delete_user("user2")
    end
  end
end
