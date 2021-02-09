defmodule Ecto.Adapters.DynamoDB.TestRepo.Migrations.AddNameIndexToCat do
  @moduledoc """
  Used when testing migrations.

  Add an index on name to the cat table. The table's provisioned throughput is [1,1],
  so here we'll apply different settings to the index.
  """
  use Ecto.Migration

  def up do
    alter table(:cat,
            options: [
              global_indexes: [
                [
                  index_name: "name",
                  keys: [:name],
                  provisioned_throughput: [2, 1],
                  create_if_not_exists: true
                ]
              ]
            ]
          ) do
      add(:name, :string, hash_key: true)
    end
  end

  def down do
    alter table(:cat,
            options: [
              global_indexes: [
                [index_name: "name", drop_if_exists: true]
              ]
            ]
          ) do
      remove(:name)
    end
  end
end
