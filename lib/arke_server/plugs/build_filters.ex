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
  alias Arke.Utils.ErrorGenerator, as: Error

  def init(default), do: default

  def call(
        %Plug.Conn{method: "GET", query_params: %{"filter" => "and" <> condition}} = conn,
        _default
      ) do
    case get_conditions(conn, remove_wrap_parentheses(condition), :and) do
      {:ok, data} -> assign(conn, :filter, data)
      {:error, msg} -> stop_conn(conn, msg)
    end
  end

  def call(
        %Plug.Conn{method: "GET", query_params: %{"filter" => "or" <> condition}} = conn,
        _default
      ) do
    case get_conditions(conn, remove_wrap_parentheses(condition), :or) do
      {:ok, data} -> assign(conn, :filter, data)
      {:error, msg} -> stop_conn(conn, msg)
    end
  end

  def call(%Plug.Conn{method: "GET", query_params: %{"filter" => filter}} = conn, _default) do
    case get_conditions(conn, filter) do
      {:ok, data} -> assign(conn, :filter, data)
      {:error, msg} -> stop_conn(conn, msg)
    end
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
      |> Enum.map(fn x ->
        case get_operator(x) do
          {:ok, op} ->
            op

          {:error, _msg} ->
            nil
        end
      end)

    if Enum.any?(operators, &is_nil(&1)) do
      Error.create(:filter, "some of the filters are not available")
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
                else: [conn, format_parameter_and_value(Enum.at(matches, i), op, negate) | acc]
          end
        end)

      error_filters = Enum.filter(filters, fn {k, v} -> k == :error end)

      if length(error_filters) > 0 do
        {:error, error_filters |> Enum.map(fn {k, v} -> v end)}
      else
        filters = Enum.filter(filters, fn {k, v} -> k == :ok end) |> Enum.map(fn {k, v} -> v end)
        {:ok, {logical_op, negate, filters}}
      end
    end
  end

  defp format_parameter_and_value(conn, data, operator, negate \\ false)

  defp format_parameter_and_value(conn, data, :isnull, _negate) do
    get_condition(conn, data, :isnull, nil, false)
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

    case Arke.Boundary.ParameterManager.get(parameter_id, project) do
      {:error, msg} ->
        {:error, msg}

      parameter ->
        {:ok, QueryManager.condition(parameter, operator, parse_value(value, operator), negate)}
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

  defp get_operator(_invalid_filter), do: Error.create(:filter, "filter not available")

  defp stop_conn(conn, errors) do
    ArkeServer.ResponseManager.send_resp(conn, 400, nil, errors)
    |> Plug.Conn.halt()
  end
end
