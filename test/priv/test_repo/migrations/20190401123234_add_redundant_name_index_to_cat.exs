defmodule Ecto.Adapters.DynamoDB.TestRepo.Migrations.AddRedundantNameIndexToCat do
  @moduledoc """
  Used when testing migrations.

  Attempt to add a redundant index to the cat table.
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
    # For testing, we'll skip dropping the index here, as that would break the down
    # function in the preceding migration, which undoes a modification made to the name index.
    # This would normally cause an error, but we'll ignore that here, it does us no good.
  end
end
