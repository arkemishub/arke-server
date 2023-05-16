defmodule ArkeServer.Openapi.Responses do

  alias OpenApiSpex.Operation

  def get_responses(exclude \\ nil)

  def get_responses(exclude) when is_list(exclude) do
    responses = %{
      200 => Operation.response("Ok", "application/json", nil),
      201 => Operation.response("Created", "application/json", nil),
      204 => Operation.response("No content", "application/json", nil),
      400 => Operation.response("Bad request", "application/json", nil),
      401 => Operation.response("Not authorized", "application/json", nil),
      404 => Operation.response("Not found", "application/json", nil)
    }

    Map.filter(responses, fn {k, v} -> k not in exclude end)
  end

  def get_responses(exclude), do: get_responses([exclude])
end
