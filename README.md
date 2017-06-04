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

## Caching

The adapter automatically caches its own calls to **describe_table** for retrieval of table information. We also offer the option to configure tables for scan caching (see configuration options below). To update the cache after making a change in a table, the cache offers two functions:

**Ecto.Adapters.DynamoDB.Cache.update_table_info!(table_name)**, *table_name* :: string

**Ecto.Adapters.DynamoDB.Cache.update_cached_table!(table_name)**, *table_name* :: string

## Configuration Options

**:scan_limit** :: integer, *default:* `100`

Sets the limit on the number of records scanned in the current query. Included as **limit** in the DynamoDB query. (Removed from queries during recursive fetch.)

**:scan_tables** :: [string], *default:* `[]`

A list of table names for tables pre-approved for a DynamoDB **scan** command in case an indexed field is not provided in the query *wheres*.

**:scan_all** :: boolean, *default:* `false`

Pre-approves all tables for a DynamoDB **scan** command in case an indexed field is not provided in the query *wheres*.

**:cached_tables** :: [string], *default:* `[]`

A list of table names for tables assigned for caching of the first page of results up to **:scan_limit**. (TODO: recursive full caching yet to be implemented).

**:insert_nil_fields** :: boolean, *default:* `true`

Determines if fields in the changeset with `nil` values will be inserted as DynamoDB `null` values or not set at all. This option is also available inline per query. Please note that DynamoDB does not allow setting indexed attributes to `null` and will respond with an error. It does allow removal of those attributes.

**:remove_nil_fields_on_update** :: boolean, *default:* `false`

Determines if, during **Repo.update** or **Repo.update_all**, fields in the changeset with `nil` values will be removed from the record/s or set to the DynamoDB `null` value. This option is also available inline per query.

## Inline Options

Please note that in order for Ecto to recognize options, the preceding parameters have to be clearly delineated. The query is enclosed in parentheses and updates are enclosed in brackets, `[]`. For example, these options would be parsed,

`Repo.update_all((from ModelName, where: [attribute: value]), [set: [attribute: new_value]], option_field: option_value)`

but these would throw an error:

`Repo.update_all(from ModelName, where: [attribute: value], set: [attribute: new_value], option_field: option_value)`

#### **Inline Options:** *Repo.all, Repo.update_all, Repo.delete_all*

**:query_info** :: boolean, *default:* false

If you would like the last evaluated key even when no results are returned from the current page, include the option, **query_info: true**. The returned map is prepended to the regular result list (or added to the tuple, in the case of delete_ and update_all) and corresponds with DynamoDb's return values:

`%{"Count" => 10, "LastEvaluatedKey" => %{"id" => %{"S" => "6814"}}, "ScannedCount" => 100}`

**:scan_limit** :: integer, *default:* set in configuration

Sets the limit on the number of records scanned in the current query. Included as **limit** in the DynamoDB query.

**:scan** :: boolean, *default:* `false` (also depends on scan-related configuration)

Approves a DynamoDB **scan** command for the current query in case an indexed field is not provided in the query *wheres*.

**:exclusive_start_key** :: [key_atom: value], *default:* none

Adds DynamoDB's **ExclusiveStartKey** to the current query, providing a starting offset.

**:recursive** :: boolean, *default:* `false`

Fetches all pages recursively and performs the relevant operation on results in the case of *Repo.update_all* and *Repo.delete_all*

#### **Inline Options:** *Repo.insert, Repo.insert_all*

**:insert_nil_fields** :: boolean, *default:* set in configuration

Determines if fields in the changeset with `nil` values will be inserted as DynamoDB `null` values or not set at all.

#### **Inline Options:** *Repo.update, Repo.update_all*

**:remove_nil_fields** :: boolean, *default:* set in configuration

Determines if fields in the changeset with `nil` values will be removed from the record/s or set to the DynamoDB `null` value.

### `is_nil` Queries

We support `is_nil` in query `wheres`. This will query DynamoDB for the attribute either set to `null` or to be missing from the record.  Please note that DynamoDB does not allow filtering for `null` or missing-attribute on attributes that are part of the current query's key conditions.

### DynamoDB `between` and Ecto `:fragment`

We currently only support the Ecto fragment of the form:

`from(m in Model, where: fragment("? between ? and ?", m.attribute, ^range_start, ^range_end)`

## Ecto Associations and Migrations

We currently do not support Ecto associations or migrations; we are looking forward to developing these features.

## Developer Notes

The **projection_expression** option is used internally during **delete_all** to select only the key attributes and is recognized during query construction.
