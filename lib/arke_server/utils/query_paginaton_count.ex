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

defmodule ArkeServer.Utils.QueryPaginationCount do
  alias Arke.QueryManager
  alias ArkeServer.Utils.{QueryOrder}

  def is_count_only(conn),
    do: Map.get(conn.query_params, "count_only", false) in ["true", true, "True", 1, "1"]

  def apply_pagination_or_count(query, conn) do
    offset = Map.get(conn.query_params, "offset", nil)
    limit = Map.get(conn.query_params, "limit", nil)
    order = Map.get(conn.query_params, "order", [])

    if is_count_only(conn) do
      {QueryManager.count(query), nil}
    else
      QueryOrder.apply_order(query, order)
      |> QueryManager.pagination(offset, limit)
    end
  end
end
