import Config

config :macfly, :http, Macfly.HTTP.Client

import_config "#{config_env()}.exs"
