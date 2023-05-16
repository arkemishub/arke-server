import Config

config :arke,
  persistence: %{
    arke_postgres: %{
      create: &ArkeServer.Support.Persistence.create/2,
      update: &ArkeServer.Support.Persistence.update/2,
      delete: &ArkeServer.Support.Persistence.delete/2,
      execute_query: &ArkeServer.Support.Persistence.execute_query/2,
      get_parameters: &ArkeServer.Support.Persistence.get_parameters/0,
      create_project: &ArkeServer.Support.Persistence.create_project/1,
      delete_project: &ArkeServer.Support.Persistence.delete_project/1
    }
  }

config :arke_auth, ArkeAuth.Guardian,
  issuer: "arke_auth",
  secret_key: "5hyuhkszkm8jilkDxrXGTBz1z1KJk5dtVwLgLOXHQRsPEtxii3wFcAbx4Gtj1aQB",
  verify_issuer: true,
  token_ttl: %{"access" => {7, :days}, "refresh" => {30, :days}}
