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

  def apply_query_filters(query, {logic, negate, filters}) when is_list(filters) do
    #    Enum.reduce(filters, query, fn filter, new_query ->
    #      apply_filter(new_query, filter)
    #    end)
    apply_filter(query, logic, negate, filters)
  end

  def apply_query_filters(query, _filters), do: query

  defp apply_filter(query, :and, negate, filters), do: QueryManager.and_(query, negate, filters)
  defp apply_filter(query, :or, negate, filters), do: QueryManager.or_(query, negate, filters)
end
