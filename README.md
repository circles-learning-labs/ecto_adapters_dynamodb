# Ecto.Adapters.DynamoDB

DynamoDB Adapter for Ecto ORM.

Before pushing commits, run `$ mix test` and confirm that processes are error-free.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ecto_adapters_dynamodb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:ecto_adapters_dynamodb, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ecto_adapters_dynamodb](https://hexdocs.pm/ecto_adapters_dynamodb).

OPTIONS:
Repo.Update: An update query will set nil fields to Dynamo's 'null' value (which can generate an error if the field is indexed), unless the option 'remove_nil_fields: true' is set. For example: Repo.update(changeset, remove_nil_fields: true)

Repo.update_all: Since Ecto :update_all does not seem to allow for arbitrary options, nil fields will set to null by default, unless the Application environment variable, ':remove_nil_fields_on_update_all' is set to 'true'. For example: 'config :ecto_adapters_dynamodb, remove_nil_fields_on_update_all: true'
