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

defmodule ArkeServer.Utils.QueryProcessor do
  alias Arke.QueryManager
  alias ArkeServer.Utils.{QueryOrder}

  def process_query(query, %{"count_only" => count_only})
      when count_only in [true, "true", "True", "1"],
      do: {QueryManager.count(query), nil}

  def process_query(query, opts) do
    QueryOrder.apply_order(query, Map.get(opts, "order"))
    |> QueryManager.pagination(Map.get(opts, "offset"), Map.get(opts, "limit"))
  end
end
