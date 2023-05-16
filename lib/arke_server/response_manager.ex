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

defmodule ArkeServer.ResponseManager do
  @moduledoc """
  Module to standardize the responses.
  The response body can be formatted as follow:
    - %{items: [...], count: integer, messages: [...]}
    - %{content: %{items: [...], count: integer, messages: [...]}}
    - {content: ..., messages: [...]}
  If the status is 204 then the body will be empty

  """
  import Plug.Conn

  defp get_content(%{items: items, count: count}, _encode) do
    %{content: %{items: items, count: count}}
  end

  defp get_content(%{items: items}, encode) do
    get_content(%{items: items, count: length(items)}, encode)
  end

  defp get_content(%{content: content}, _encode) do
    %{content: content}
  end

  defp get_content(nil, _encode), do: %{content: nil}
  defp get_content("", _encode), do: %{content: nil}

  defp get_content(content, _encode) do
    %{content: content}
  end

  def send_resp(conn, status, data, message \\ [], encode \\ :json)

  def send_resp(conn, status, data, message, encode) when is_list(message) do
    send_response(conn, status, data, message, encode)
  end

  @doc false
  def send_resp(conn, status, data, message, encode) when is_map(message) do
    send_response(conn, status, data, [message], encode)
  end

  def send_resp(conn, status, data, message, encode) when is_binary(message) do
    send_response(conn, status, data, [%{context: nil, message: message}], encode)
  end

  def send_resp(conn, status, _data, _message, _encode) do
    Plug.Conn.send_resp(conn, status, "")
  end

  @doc false
  def send_resp(conn, 204), do: Plug.Conn.send_resp(conn, 204, "")

  defp send_response(conn, status, data, messages, encode) do
    data =
      get_content(data, encode)
      |> Map.put_new(:messages, messages)

    with {:ok, data} <- Jason.encode(data) do
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, data)
    else
      _ -> Plug.Conn.send_resp(conn, 400, "invalid data format")
    end
  end
end
