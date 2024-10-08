import Config

config :ecto_adapters_dynamodb, Ecto.Adapters.DynamoDB.TestRepo,
  migration_source: "test_schema_migrations",
  debug_requests: true,
  # Unlike for prod config, we hardcode fake values for local version of DynamoDB
  access_key_id: "abcd",
  secret_access_key: "1234",
  region: "us-east-1",
  dynamodb: [
    scheme: "http://",
    host: "localhost",
    port: 8000,
    region: "us-east-1"
  ],
  scan_tables: ["test_schema_migrations"],
  dynamodb_local: true

config :ecto_adapters_dynamodb,
  log_levels: []

config :logger,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: :debug]
  ],
  level: :info
