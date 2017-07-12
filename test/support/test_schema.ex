defmodule Ecto.Adapters.DynamoDB.TestSchema.Person do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  
  schema "test_person" do
    field :first_name, :string
    field :last_name,  :string
    field :age,        :integer
    field :email,      :string
    field :password,   :string
    field :circles,    {:array, :string}
  end

  def changeset(person, params \\ %{}) do
    person
    |> Ecto.Changeset.cast(params, [:first_name, :last_name, :age, :email, :password, :circles])
    |> Ecto.Changeset.validate_required([:first_name, :last_name])
    |> Ecto.Changeset.unique_constraint(:id)
  end

  def get_fields() do
    @changeset_fields
  end
end

# This is used to test records that have a hash+range primary key
# However there's no way to specify this on the Ecto side: we just
# tell Ecto that the hash key (:id) is the primary key, and that the
# range key (:page_num) is a required field.
defmodule Ecto.Adapters.DynamoDB.TestSchema.BookPage do
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "test_book_page" do
    field :page_num, :integer
    field :text,     :string
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
