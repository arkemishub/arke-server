import Config

config :logger, level: :info
config :phoenix, :json_library, Jason
import_config "#{config_env()}.exs"
