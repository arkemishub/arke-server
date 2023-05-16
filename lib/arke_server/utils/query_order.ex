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

defmodule ArkeServer.Utils.QueryOrder do
  alias Arke.QueryManager

  def apply_order(query, []), do: query

  def apply_order(query, [current | tail]) do
    case String.split(current, ";") do
      [parameter, direction] ->
        apply_order(
          QueryManager.order(query, parameter, String.to_existing_atom(direction)),
          tail
        )

      _ ->
        nil
    end
  end

  def apply_order(query, order) do
    apply_order(query, [order])
  end
end
