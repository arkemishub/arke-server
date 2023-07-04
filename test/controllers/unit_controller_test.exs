defmodule ArkeServer.UnitControllerTest do
  use ArkeServer.ConnCase
  require IEx

  defp check_unit(_context) do
    values = [
      id: :unit_support_api,
      label: "test",
      string_support: "String value",
      enum_string_support: "first",
      integer_support: 4,
      enum_integer_support: 4,
      float_support: 8.0,
      enum_float_support: 3.5,
      boolean_support: true,
      list_support: ["value", "list"]
    ]

    values_unit_2 = [
      id: :unit_support_api_2,
      string_support: "Second unit",
      enum_string_support: "second",
      label: "test_2",
      integer_support: 12,
      enum_integer_support: 1,
      float_support: 6.12,
      enum_float_support: 2,
      boolean_support: false
    ]

    values_unit_3 = [
      id: :unit_support_api_3,
      enum_string_support: "third",
      integer_support: 12,
      enum_integer_support: 1,
      float_support: 6.12,
      enum_float_support: 2,
      boolean_support: false
    ]

    check_db(values[:id])
    check_db(values_unit_2[:id])
    check_db(values_unit_3[:id])
    model = ArkeManager.get(:arke_test_support, :arke_system)

    QueryManager.create(:test_schema, model, values)
    QueryManager.create(:test_schema, model, values_unit_2)
    QueryManager.create(:test_schema, model, values_unit_3)

    :ok
  end

  defp auth_conn(_context) do
    user = get_user()
    %{auth_conn: build_authenticated_conn(user)}
  end

  describe "get unit by filters AND - GET /lib/unit" do
    setup [:check_unit, :auth_conn]

    test "eq", %{auth_conn: conn} = _context do
      filter = "filter=and(eq(string_support,Second unit))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert List.first(json_body["content"]["items"])["string_support"] == "Second unit"
    end

    test "gt", %{auth_conn: conn} = _context do
      filter = "filter=and(gt(integer_support,4),gt(float_support,10.0))"

      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert List.first(json_body["content"]["items"])["integer_support"] > 4 == true
      assert List.first(json_body["content"]["items"])["float_support"] > 10.0 == true
    end

    test "gte", %{auth_conn: conn} = _context do
      filter = "filter=and(gte(integer_support,6),gte(float_support,6.0))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert List.first(json_body["content"]["items"])["integer_support"] >= 6 == true
      assert List.first(json_body["content"]["items"])["float_support"] >= 6.0 == true
    end

    test "lt", %{auth_conn: conn} = _context do
      filter = "filter=and(lt(integer_support,15),lt(float_support,8.5))"

      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert List.first(json_body["content"]["items"])["integer_support"] < 10 == true
      assert List.first(json_body["content"]["items"])["float_support"] < 8.5 == true
    end

    test "lte", %{auth_conn: conn} = _context do
      # FIXME: unit_support_api_2
      filter = "filter=and(lte(integer_support,10),lte(float_support,8.5))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert List.first(json_body["content"]["items"])["integer_support"] <= 10 == true
      assert List.first(json_body["content"]["items"])["float_support"] <= 8.5 == true
    end

    test "endswith", %{auth_conn: conn} = _context do
      filter = "filter=and(endswith(string_support,it))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert List.first(json_body["content"]["items"])["string_support"] == "Second unit"
    end

    test "iendswith", %{auth_conn: conn} = _context do
      filter = "filter=and(iendswith(string_support,IT))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert List.first(json_body["content"]["items"])["string_support"] == "Second unit"
    end

    test "startswith", %{auth_conn: conn} = _context do
      filter = "filter=and(startswith(string_support,Sec))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert List.first(json_body["content"]["items"])["string_support"] == "Second unit"
    end

    test "istartswith", %{auth_conn: conn} = _context do
      filter = "filter=and(istartswith(string_support,SECO))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert List.first(json_body["content"]["items"])["string_support"] == "Second unit"
    end

    test "contains", %{auth_conn: conn} = _context do
      filter = "filter=and(contains(string_support,S))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert json_body["content"]["count"] > 0

      assert is_nil(
               Enum.find(json_body["content"]["items"], fn item ->
                 item["id"] == "unit_support_api"
               end)
             ) == false
    end

    test "icontains", %{auth_conn: conn} = _context do
      filter = "filter=and(icontains(string_support,s))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert json_body["content"]["count"] > 0

      assert is_nil(
               Enum.find(json_body["content"]["items"], fn item ->
                 item["id"] == "unit_support_api"
               end)
             ) == false
    end

    test "in", %{auth_conn: conn} = _context do
      # FIXME: support of in operator with numbers
      filter = "filter=and(in(integer_support,(3,10)))"

      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      param = List.first(json_body["content"]["items"])["integer_support"]
      assert param >= 3 and param <= 10 == true
    end

    test "isnull", %{auth_conn: conn} = _context do
      filter = "filter=and(isnull(string_support))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)
      param = List.first(json_body["content"]["items"])["string_support"]

      assert is_nil(param) == true and
               List.first(json_body["content"]["items"])["id"] == "unit_support_api_3"
    end
  end

  describe "get unit by filters OR - GET /lib/unit" do
    setup [:check_unit, :auth_conn]

    test "eq", %{auth_conn: conn} = _context do
      filter = "filter=or(eq(string_support,Not valid unit),eq(string_support,Second unit))"

      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert List.first(json_body["content"]["items"])["string_support"] == "Second unit"
    end

    test "gt", %{auth_conn: conn} = _context do
      filter = "filter=or(gt(integer_support,4),gt(integer_support,20))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      unit = List.first(json_body["content"]["items"])

      assert unit["id"] == "unit_support_api_2"
    end

    test "gte", %{auth_conn: conn} = _context do
      filter = "filter=or(gte(integer_support,6),gte(integer_support,20))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)
      unit = List.first(json_body["content"]["items"])

      assert unit["id"] == "unit_support_api_2"
    end

    test "lt", %{auth_conn: conn} = _context do
      filter = "filter=or(lt(integer_support,10),lt(float_support,20.0))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      unit = List.first(json_body["content"]["items"])

      assert unit["id"] == "unit_support_api"
    end

    test "lte", %{auth_conn: conn} = _context do
      # FIXME: Float like 20 should be accepted
      filter = "filter=or(lte(integer_support,10),lte(float_support,20))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      unit = List.first(json_body["content"]["items"])

      assert unit["id"] == "unit_support_api_2"
    end

    test "endswith", %{auth_conn: conn} = _context do
      # FIXME: unit_support_api_2
      filter = "filter=or(endswith(string_support,it),endswith(string_support,uno))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)
      unit = List.first(json_body["content"]["items"])

      assert unit["id"] == "unit_support_api_2"
    end

    test "iendswith", %{auth_conn: conn} = _context do
      filter = "filter=or(iendswith(string_support,IT),iendswith(string_support,UNO))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)
      unit = List.first(json_body["content"]["items"])

      assert unit["id"] == "unit_support_api_2"
    end

    test "startswith", %{auth_conn: conn} = _context do
      filter = "filter=or(startswith(string_support,Sec))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)
      unit = List.first(json_body["content"]["items"])

      assert unit["id"] == "unit_support_api_2"
    end

    test "istartswith", %{auth_conn: conn} = _context do
      filter = "filter=or(istartswith(string_support,SEC))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert List.first(json_body["content"]["items"])["string_support"] == "Second unit"
    end

    test "contains", %{auth_conn: conn} = _context do
      filter = "filter=or(contains(string_support,S))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert json_body["content"]["count"] > 0

      assert is_nil(
               Enum.find(json_body["content"]["items"], fn item ->
                 item["id"] == "unit_support_api"
               end)
             ) == false
    end

    test "icontains", %{auth_conn: conn} = _context do
      filter = "filter=or(icontains(string_support,s))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)

      assert json_body["content"]["count"] > 0

      assert is_nil(
               Enum.find(json_body["content"]["items"], fn item ->
                 item["id"] == "unit_support_api"
               end)
             ) == false
    end

    test "in", %{auth_conn: conn} = _context do
      # FIXME: list of values
      filter = "filter=or(in(integer_support,(3,10)))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)
      param = List.first(json_body["content"]["items"])["integer_support"]
      assert param >= 3 and param <= 10 == true
    end

    test "isnull", %{auth_conn: conn} = _context do
      filter = "filter=or(isnull(string_support))"
      conn = get(conn, "/lib/unit?#{filter}")

      json_body = json_response(conn, 200)
      param = List.first(json_body["content"]["items"])["string_support"]

      assert is_nil(param) == true and
               List.first(json_body["content"]["items"])["id"] == "unit_support_api_3"
    end
  end
end
