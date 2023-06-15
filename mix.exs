defmodule ArkeServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :arke_server,
      version: "0.1.5",
      build_path: "./_build",
      config_path: "./config/config.exs",
      deps_path: "./deps",
      lockfile: "./mix.lock",
      elixir: "~> 1.13",
      dialyzer: [plt_add_apps: ~w[eex]a],
      description: description(),
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: false],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ArkeServer.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    List.flatten([
      {:phoenix, "~> 1.6.6"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:guardian, "~> 2.2.3"},
      {:corsica, "~> 1.2"},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:open_api_spex, "~> 3.16"},
      {:ymlr, "~> 2.0", only: :dev},
      {:excoveralls, "~> 0.10", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:arke_postgres, "~> 0.1.8", only: :test},
      {:arke, "~> 0.1.7"},
      {:arke_auth, "~> 0.1.4"}
    ])
  end

  defp aliases do
    [
      test: ["arke_postgres.init_db --quiet", "test"],
      "test.ci": ["arke_postgres.init_db --quiet", "test"],
      setup: ["deps.get"]
    ]
  end

  defp description() do
    "Arke server"
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "arke_server",
      # These are the default files included in the package
      licenses: ["Apache-2.0"],
      links: %{
        "Website" => "https://arkehub.com",
        "Github" => "https://github.com/arkemishub/arke-server"
      }
    ]
  end
end
