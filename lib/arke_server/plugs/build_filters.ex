# Copyright 2023 Arkemis S.r.l.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule ArkeServer.Plugs.BuildFilters do
  import Plug.Conn
  alias Arke.QueryManager
  alias Arke.Validator

  def init(default), do: default

  def call(
        %Plug.Conn{method: "GET", query_params: %{"filter" => "and" <> condition}} = conn,
        _default
      ) do
    assign(conn, :filter, get_conditions(conn, remove_wrap_parentheses(condition), :and))
  end

  def call(
        %Plug.Conn{method: "GET", query_params: %{"filter" => "or" <> condition}} = conn,
        _default
      ) do
    assign(conn, :filter, get_conditions(conn, remove_wrap_parentheses(condition), :or))
  end

  def call(%Plug.Conn{method: "GET", query_params: %{"filter" => filter}} = conn, _default) do
    assign(conn, :filter, get_conditions(conn, filter))
  end

  def call(conn, _opts), do: conn

  defp remove_wrap_parentheses(str) do
    String.slice(str, 1..(String.length(str) - 2))
  end

  defp get_conditions(
         conn,
         base_condition,
         logical_op \\ :and,
         is_filter \\ true,
         negate \\ false
       ) do
    matches =
      Regex.scan(~r/\((?:[^)(]+|(?R))*+\)/, base_condition)
      |> Enum.map(fn m -> Enum.at(m, 0) |> remove_wrap_parentheses() end)

    operators =
      Enum.reduce(matches, base_condition, fn match, acc ->
        remove_match(match, acc)
      end)
      |> String.split(",")
      |> Enum.map(fn x -> get_operator(x) end)

    filters =
      Enum.with_index(operators)
      |> Enum.reduce([], fn {op, i}, acc ->
        cond do
          is_logic_operator(op) ->
            [get_conditions(conn, Enum.at(matches, i), op, false) | acc]

          is_negate_operator(op) ->
            if is_filter,
              do: [get_conditions(conn, Enum.at(matches, i), op, false, true) | acc],
              else: [get_conditions(conn, Enum.at(matches, i), op, false, true) | acc]

          true ->
            if is_filter,
              do: [format_parameter_and_value(conn, Enum.at(matches, i), op, negate) | acc],
              else: [conn, format_parameter_and_value(Enum.at(matches, i), op, negate) | acc]
        end
      end)

    {logical_op, negate, filters}
  end

  defp format_parameter_and_value(conn, data, operator, negate \\ false) do
    project = conn.assigns[:arke_project]
    [parameter, value] = String.split(data, ",")
    # TODO handle if parameter not exists
    parameter = Arke.Boundary.ParameterManager.get(parameter, project)
    # TODO handle if parameter not valid
    test = Validator.validate_parameter(nil, parameter.id, value, :arke_system)
    QueryManager.condition(parameter.id, operator, value, negate)
  end

  defp remove_match(match, str) do
    String.replace(str, match, "")
  end

  defp is_logic_operator(:or), do: true
  defp is_logic_operator(:and), do: true
  defp is_logic_operator(_op), do: false

  defp is_negate_operator(:not), do: true
  defp is_negate_operator(_op), do: false

  defp get_operator("or()"), do: :or
  defp get_operator("and()"), do: :and

  defp get_operator("not()"), do: :not

  defp get_operator("eq()"), do: :eq
  defp get_operator("contains()"), do: :contains
  defp get_operator("icontains()"), do: :icontains
  defp get_operator("startswith()"), do: :startswith
  defp get_operator("istartswith()"), do: :istartswith
  defp get_operator("endswith()"), do: :endswith
  defp get_operator("iendswith()"), do: :iendswith
  defp get_operator("lte()"), do: :lte
  defp get_operator("lt()"), do: :lt
  defp get_operator("gt()"), do: :gt
  defp get_operator("gte()"), do: :gte
  defp get_operator("in()"), do: :in
end
