use Mix.Config

config :ecto_adapters_dynamodb, Ecto.Adapters.DynamoDB.TestRepo,
  adapter: Ecto.Adapters.DynamoDB,
  # ExAws configuration
  access_key_id: "abcd",    # Unlike for prod config, we hardcode fake values for local version of dynamo DB
  secret_access_key: "1234",
  region: "us-east-1",
  dynamodb: [
    scheme: "http://",
    host: "localhost",
    port: 8000,
    region: "us-east-1"
  ]

config :ecto_adapters_dynamodb,
  cached_tables: ["role"],
  log_levels: []

config :logger,
  backends: [:console],
  compile_time_purge_level: :debug,
  level: :info
