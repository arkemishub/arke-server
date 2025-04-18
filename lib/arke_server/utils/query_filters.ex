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

defmodule ArkeServer.Utils.QueryFilters do
  alias Arke.QueryManager
  alias Arke.Utils.ErrorGenerator, as: Error

  def apply_query_filters(query, {logic, negate, filters}) when is_list(filters) do
    #    Enum.reduce(filters, query, fn filter, new_query ->
    #      apply_filter(new_query, filter)
    #    end)
    apply_filter(query, logic, negate, filters)
  end

  def apply_query_filters(query, _filters), do: query

  def apply_member_child_only(query, member, true) when not is_nil(member) do
    QueryManager.link(query, member, depth: 10)
  end

  def apply_member_child_only(query, _, _), do: query

  defp apply_filter(query, :and, negate, filters), do: QueryManager.and_(query, negate, filters)
  defp apply_filter(query, :or, negate, filters), do: QueryManager.or_(query, negate, filters)

  def get_from_string(conn, nil), do: {:ok, nil}

  def get_from_string(conn, "and" <> condition),
    do: get_conditions(conn, remove_wrap_parentheses(condition), :and)

  def get_from_string(conn, "or" <> condition),
    do: get_conditions(conn, remove_wrap_parentheses(condition), :or)

  def get_from_string(conn, condition), do: get_conditions(conn, condition)

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
      Regex.scan(~r/(?:\(+)(.+?)(?:\)+)/, base_condition, capture: :first)
      |> Enum.map(fn m -> Enum.at(m, 0) |> remove_wrap_parentheses() end)

    operator_list =
      Enum.reduce(matches, base_condition, fn match, acc ->
        remove_match(match, acc)
      end)
      |> String.split(",")
      |> Enum.reduce(%{error: [], operator: []}, fn x, acc ->
        case get_operator(x) do
          {:ok, op} ->
            Map.update(acc, :operator, [], fn old -> old ++ [op] end)

          {:error, msg} ->
            Map.update(acc, :error, [], fn old -> msg ++ old end)
        end
      end)

    errors = Map.get(operator_list, :error)
    operators = Map.get(operator_list, :operator)

    if length(errors) > 0 do
      {:error, errors}
    else
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
                else: [format_parameter_and_value(conn, Enum.at(matches, i), op, negate) | acc]
          end
        end)

      error_filters = Enum.filter(filters, fn {k, v} -> k == :error end)

      if length(error_filters) > 0 do
        {:error, error_filters |> Enum.map(fn {k, v} -> v end)}
      else
        filters = Enum.filter(filters, fn {k, v} -> k == :ok end) |> Enum.map(fn {k, v} -> v end)

        if negate == true do
          {:ok, List.first(filters)}
        else
          {:ok, {logical_op, negate, filters}}
        end
      end
    end
  end

  defp format_parameter_and_value(conn, data, operator, negate \\ false)

  defp format_parameter_and_value(conn, data, :isnull, negate) do
    get_condition(conn, data, :isnull, nil, negate)
  end

  defp format_parameter_and_value(conn, data, operator, negate) do
    case String.split(data, ",", parts: 2) do
      [parameter_id, value] ->
        case get_condition(conn, parameter_id, operator, value, negate) do
          {:error, msg} -> {:error, msg}
          {:ok, condition} -> {:ok, condition}
        end

      _ ->
        Error.create(:filter, "invalid value. Use `isnull()` operator to check null values")
    end
  end

  defp get_condition(conn, parameter_id, operator, value, negate) do
    project = conn.assigns[:arke_project]

    {parameter_id, path_ids} =
      parameter_id
      |> String.split(".")
      |> List.pop_at(-1)

    with {:ok, parameter} <- fetch_parameter(parameter_id, project),
         {:ok, path} <- get_path_parameters(path_ids, project) do
      {:ok,
       QueryManager.condition(parameter, operator, parse_value(value, operator), negate, path)}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  defp get_path_parameters(path_ids, project) do
    Enum.reduce_while(path_ids, {:ok, []}, fn path_id, {:ok, acc} ->
      case fetch_parameter(path_id, project) do
        {:ok, parameter} -> {:cont, {:ok, [parameter | acc]}}
        {:error, msg} -> {:halt, {:error, msg}}
      end
    end)
    |> case do
      {:ok, path} -> {:ok, Enum.reverse(path)}
      error -> error
    end
  end

  defp fetch_parameter(parameter_id, project) do
    case Arke.Boundary.ParameterManager.get(parameter_id, project) do
      {:error, msg} -> {:error, msg}
      parameter -> {:ok, parameter}
    end
  end

  defp remove_match(match, str) do
    String.replace(str, match, "")
  end

  defp parse_value(val, :in) do
    # remove ( and ) from our string before split
    String.replace(val, ~r'[\(\])]', "")
    |> String.split(",")
  end

  defp parse_value(v, _operator), do: v

  defp is_logic_operator(:or), do: true
  defp is_logic_operator(:and), do: true
  defp is_logic_operator(_op), do: false

  defp is_negate_operator(:not), do: true
  defp is_negate_operator(_op), do: false

  defp get_operator("or(" <> _rest), do: {:ok, :or}
  defp get_operator("and(" <> _rest), do: {:ok, :and}

  defp get_operator("not(" <> _rest), do: {:ok, :not}

  defp get_operator("eq(" <> _rest), do: {:ok, :eq}
  defp get_operator("contains(" <> _rest), do: {:ok, :contains}
  defp get_operator("icontains(" <> _rest), do: {:ok, :icontains}
  defp get_operator("startswith(" <> _rest), do: {:ok, :startswith}
  defp get_operator("istartswith(" <> _rest), do: {:ok, :istartswith}
  defp get_operator("endswith(" <> _rest), do: {:ok, :endswith}
  defp get_operator("iendswith(" <> _rest), do: {:ok, :iendswith}
  defp get_operator("lte(" <> _rest), do: {:ok, :lte}
  defp get_operator("lt(" <> _rest), do: {:ok, :lt}
  defp get_operator("gt(" <> _rest), do: {:ok, :gt}
  defp get_operator("gte(" <> _rest), do: {:ok, :gte}
  defp get_operator("in(" <> _rest), do: {:ok, :in}
  defp get_operator("isnull(" <> _rest), do: {:ok, :isnull}

  defp get_operator(invalid_filter),
    do: Error.create(:filter, "filter `#{invalid_filter}` not available")
end
