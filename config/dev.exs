use Mix.Config

config :ex_aws,
  debug_requests: true,
  access_key_id: "abcd",    # Unlike for prod config, we hardcode fake values for local version of dynamo DB
  secret_access_key: "1234",
  region: "us-east-1"

config :ex_aws, :dynamodb,
  scheme: "http://",
  host: "localhost",
  port: 8000,
  region: "us-east-1"

config :ex_aws, :dynamodb_streams,
  scheme: "http://",
  host: "localhost",
  port: 8000,
  region: "us-east-1"


