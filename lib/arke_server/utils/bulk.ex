defmodule ArkeServer.Utils.Bulk do
  alias Arke.StructManager

  def build_response_content(conn, count, valid, errors) do
    load_links = Map.get(conn.query_params, "load_links", "false") == "true"
    load_values = Map.get(conn.query_params, "load_values", "false") == "true"
    load_files = Map.get(conn.query_params, "load_files", "false") == "true"
    return_units = Map.get(conn.query_params, "return_units", "false") == "true"

    error_units =
      Enum.map(errors, fn {unit, unit_errors} ->
        Map.put(
          StructManager.encode(unit,
            load_links: load_links,
            load_values: load_values,
            load_files: load_files,
            type: :json
          ),
          "errors",
          unit_errors
        )
      end)

    response = %{
      success_count: count,
      error_count: length(error_units),
      error_units: error_units
    }

    case return_units do
      true ->
        Map.put(response, :units, StructManager.encode(valid, type: :json))

      false ->
        response
    end
  end
end
