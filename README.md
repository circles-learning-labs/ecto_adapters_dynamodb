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


TODO: organize this
##Scan
Inline options are (with examples): `scan_limit: 100` (DynamoDB's limit on the total items scanned), `exclusive_start_key: [id: "some_id"]`, `fetch_all: true` (fetches all pages recursively), and `scan: true` (available globally in config as `:scan_all`). The last one enables the scan if the table is not already in the preconfigured lists, `:cached_tables` or `:scan_tables`. A default `:scan_limit` of 100 can be overridden either in the configuration or inline.
Please notice that Ecto queries are greedy: 
'Repo.all(from Model, where: [name: "Name"], scan_limit: 250)'
is not the same as, 
'Repo.all((from Model, where: [name: "Name"]), scan_limit: 250)'


is_nil queries: we support is_nil; please note that DynamoDB does not allow filtering for 'null' or missing-attribute on attributes that are part of the current query's key.


DynamoDB "between" query and Ecto :fragment
We currently only support the Ecto fragment of the form, 'from(m in Model, where: fragment("? between ? and ?", m.attribute, ^range_start, ^range_end)'


OPTIONS:
Repo.insert / Repo.insert_all: add the option, 'insert_nil_fields: false', to prevent nil fields defined in the model's schema from being inserted. For example: Repo.insert(changeset, insert_nil_fields: false)
This can also be set globally in the application's configuration: 
'config :ecto_adapters_dynamodb, insert_nil_fields: false'

Repo.All: we are currently supporting scan only as an in-memory cache for preconfigured tables.
Application configuration: config :ecto_adapters_dynamodb, cached_tables: [table_name, table_name...] , where table names are strings.

Repo.Update: An update query will set nil fields to Dynamo's 'null' value (which can generate an error if the field is indexed), unless the inline option 'remove_nil_fields: true' is set. For example: Repo.update(changeset, remove_nil_fields: true)
This can also be set globally in config :remove_nil_fields_on_update

Repo.update_all: Since Ecto :update_all does not seem to allow for arbitrary options, nil fields will set to null by default, unless the Application environment variable, ':remove_nil_fields_on_update_all' is set to 'true'. For example: 'config :ecto_adapters_dynamodb, remove_nil_fields_on_update_all: true'
