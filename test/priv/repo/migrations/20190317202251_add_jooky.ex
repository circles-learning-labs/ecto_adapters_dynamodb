defmodule Ecto.Adapters.DynamoDB.Test.Migrations.AddJookyTable do
  use Ecto.Migration

  def up do
    create_if_not_exists table(:jooky,
      primary_key: false,
      options: [
        provisioned_throughput: [1,1]
      ]) do

      add :id, :string, primary_key: true

      timestamps()
    end
  end

  def down do
    drop_if_exists table(:jooky)
  end

end
