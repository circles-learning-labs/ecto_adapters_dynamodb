use Mix.Config

config :ex_aws,
  json_codec: Poison

import_config "#{Mix.env}.exs"
