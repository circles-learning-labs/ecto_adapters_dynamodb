# Upgrading from version 2.X.X -> 3.X.X

## Config changes

With the exception of logging configuration, all config options are now per-repo. For example:

```elixir
config :ecto_adapters_dynamodb,
  dynamodb: [
    scheme: "http://",
    host: "localhost",
    port: 8000,
    region: "us-east-1"
  ],
  scan_tables: ["test_schema_migrations"]
```

now needs to be:

```elixir
config :ecto_adapters_dynamodb, MyApp.MyRepo
  dynamodb: [
    scheme: "http://",
    host: "localhost",
    port: 8000,
    region: "us-east-1"
  ],
  scan_tables: ["test_schema_migrations"]
```

(replacing `MyApp.MyRepo` with your repo).

### Global ExAws config

Prior to v3, the adapter would overwrite any existing glboal ExAws config with its own values on
startup. From v3 the adapter will only use the config it's given in the calls it makes itself.
This may mean that you need to explicitly specify ExAws configuration options outside of the
adapter's config if you're making your own ExAws calls elsewhere.
