defmodule Ecto.Adapters.DynamoDB.TestSchema.Address do
  use Ecto.Schema
  @timestamps_opts [type: :utc_datetime]

  embedded_schema do
    field :street_number, :integer
    field :street_name, :string

    timestamps()
  end
end

defmodule Ecto.Adapters.DynamoDB.TestSchema.Person do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :naive_datetime_usec]

  alias Ecto.Adapters.DynamoDB.TestSchema.Address

  schema "test_person" do
    field :first_name, :string
    field :last_name,  :string
    field :age,        :integer
    field :email,      :string
    field :password,   :string
    field :country,    :string, source: :data1
    embeds_many :addresses, Address

    timestamps()
  end

  def changeset(person, params \\ %{}) do
    person
    |> Ecto.Changeset.cast(params, [:first_name, :last_name, :age, :email, :password])
    |> Ecto.Changeset.validate_required([:first_name, :last_name])
    |> Ecto.Changeset.unique_constraint(:id)
  end

  def get_fields() do
    @changeset_fields
  end
end

# This is used to test records that have a hash+range primary key.
# Use the `primary_key: true` option on the field for the range key.
defmodule Ecto.Adapters.DynamoDB.TestSchema.BookPage do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "test_book_page" do
    field :page_num, :integer, primary_key: true
    field :text,     :string

    timestamps()
  end

  def changeset(page, params \\ %{}) do
    page
    |> Ecto.Changeset.cast(params, [:page_num, :text])
    |> Ecto.Changeset.validate_required([:page_num])
    |> Ecto.Changeset.unique_constraint(:id)
    # See this page for why we only put a constraint on :id even though
    # the real constraint is on the full primary key of hash+range:
    # https://hexdocs.pm/ecto/Ecto.Changeset.html#unique_constraint/3-complex-constraints
  end
end

defmodule Ecto.Adapters.DynamoDB.TestSchema.Planet do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "test_planet" do
    field :name, :string
    field :mass, :integer
    field :moons, Ecto.Adapters.DynamoDB.DynamoDBSet

    timestamps() # default timestamps_opts is :naive_datetime
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> Ecto.Changeset.cast(params, [:name, :moons])
    |> Ecto.Changeset.validate_required([:id, :name])
    |> Ecto.Changeset.unique_constraint(:name)
    # In order to use the test_planet table for testing fragment queries
    # on a composite primary key, we'll allow for duplicate ids but enforce unique names.
  end
end

# defmodule Ecto.Adapters.DynamoDB.TestSchema.TestSchemaMigration do
#   use Ecto.Schema

#   @primary_key {:version, :integer, []}
#   schema "test_schema_migrations" do
#     field :inserted_at, :utc_datetime
#   end
# end

# defmodule Ecto.Adapters.DynamoDB.TestSchema.TestSchemaMigration do
#   # Define a schema that works with the a table, which is schema_migrations by default
#   @moduledoc false
#   use Ecto.Schema

#   import Ecto.Query, only: [from: 2]

#   @primary_key {:version, :integer, []}
#   schema "test_schema_migrations" do
#     timestamps updated_at: false
#   end

#   @opts [timeout: :infinity, log: false]

#   def ensure_schema_migrations_table!(repo, prefix) do
#     adapter = repo.__adapter__
#     create_migrations_table(adapter, repo, prefix)
#   end

#   def migrated_versions(repo, prefix) do
#     from(p in {get_source(repo), __MODULE__}, select: p.version)
#     |> Map.put(:prefix, prefix)
#     |> repo.all(@opts)
#   end

#   def up(repo, version, prefix) do
#     %__MODULE__{version: version}
#     |> Ecto.put_meta(prefix: prefix, source: get_source(repo))
#     |> repo.insert!(@opts)
#   end

#   def down(repo, version, prefix) do
#     from(p in {get_source(repo), __MODULE__}, where: p.version == ^version)
#     |> Map.put(:prefix, prefix)
#     |> repo.delete_all(@opts)
#   end

#   def get_source(repo) do
#     Keyword.get(repo.config, :migration_source, "test_schema_migrations")
#   end

#   defp create_migrations_table(adapter, repo, prefix) do
#     table_name = repo |> get_source |> String.to_atom
#     table = %Ecto.Migration.Table{name: table_name, prefix: prefix}

#     # DDL queries do not log, so we do not need to pass log: false here.
#     adapter.execute_ddl(repo,
#       {:create_if_not_exists, table, [
#         {:add, :version, :bigint, primary_key: true},
#         {:add, :inserted_at, :naive_datetime, []}]}, @opts)
#   end
# end
