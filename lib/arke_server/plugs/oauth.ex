defmodule ArkeServer.Plugs.OAuth do
  @behaviour Plug

  # return the available routes based on the supported provider defined in the :arke_server configuration
  @impl Plug
  def init(opts \\ []) do
    env = get_env([:arke_server, Keyword.get(opts, :otp_app)])
    providers = get_provider_list(env, opts)
    base_path = get_base_path(env, opts)
    Enum.flat_map(providers, &build_routes(base_path, &1))
  end

  @impl Plug
  def call(conn, routes) do
    route_prefix = Path.join(["/" | conn.script_name])
    route_path = Path.relative_to(conn.request_path, route_prefix)
    route_key = {normalize_route_path(route_path), conn.method}

    case List.keyfind(routes, route_key, 0) do
      {_, route_mfa} ->
        run(conn, route_mfa)

      _ ->
        conn
    end
  end

  defp get_env(value) do
    case value do
      nil -> []
      name when is_atom(name) -> Application.get_env(name, __MODULE__, [])
      list when is_list(list) -> list |> Enum.map(&get_env/1) |> Enum.reduce(&Keyword.merge/2)
    end
  end

  defp build_routes(base_path, strategy) do
    # Create the routes which will be used in `call/2`. It uses a base_url (defined in the plug opts or default)
    # and the modules listed under the providers key in the configuration

    {_, {module, _}} = strategy
    strategy_options = build_strategy_options(base_path, strategy)

    request_mfa = {module, :run_request, strategy_options}
    [{{strategy_options.request_path, "POST"}, request_mfa}]
  end

  # return the enabled oauth provider from the configuration
  defp get_provider_list(environment, options) do
    with {:ok, prov_list} <- Keyword.fetch(environment, :providers) do
      case Keyword.get(options, :providers, :all) do
        :all -> prov_list
        provider_names -> Keyword.take(prov_list, provider_names)
      end
    else
      _ -> []
    end
  end

  # get the base bath used for the sso
  defp get_base_path(environment, options),
    do: Keyword.get(options, :base_url, Keyword.get(environment, :base_url, "lib/auth/signin"))

  defp normalize_route_path("/" <> _rest = route_path), do: route_path
  defp normalize_route_path(route_path), do: "/" <> route_path

  def run_request(conn, provider_name, {provider, :run_request, provider_options}, options \\ []) do
    environment = get_env([:arke_server, Keyword.get(options, :otp_app)])
    base_path = get_base_path(environment, options)

    to_options = build_strategy_options(base_path, {provider_name, {provider, provider_options}})

    run(conn, {provider, to_options})
  end

  defp run(conn, {module, :run_request, options}) do
    route_base_path = Enum.map_join(conn.script_name, &"/#{&1}")

    to_request_path = Path.join(["/", route_base_path, options.request_path])
    to_options = %{options | request_path: to_request_path}

    conn
    |> Plug.Conn.put_private(:arke_server_request_options, to_options)
    |> ArkeServer.OAuth.Core.run_request(module)
  end

  defp get_request_path(base_path, strategy) do
    {name, {_, options}} = strategy
    default_path = Path.join(["/", base_path, to_string(name)])
    String.replace_trailing(Keyword.get(options, :request_path, default_path), "/", "")
  end

  # create the struct used to find which provide module call and everything related to the request
  defp build_strategy_options(base_path, strategy) do
    {name, {module, options}} = strategy

    %{
      strategy: module,
      strategy_name: name,
      request_scheme: Keyword.get(options, :request_scheme),
      request_path: get_request_path(base_path, strategy),
      request_port: Keyword.get(options, :request_port),
      options: options
    }
  end
end
