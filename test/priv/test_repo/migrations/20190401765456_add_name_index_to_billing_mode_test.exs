defmodule Ecto.Adapters.DynamoDB.TestRepo.Migrations.AddNameIndexToBillingModeTest do
  @moduledoc """
  Used when testing migrations.

  See the moduledoc for the previous migration for an explanation of this migration's purpose.
  """
  use Ecto.Migration

  def up do
    alter table(:billing_mode_test,
      options: [
        global_indexes: [
          [index_name: "name",
            keys: [:name],
            create_if_not_exists: true]
        ]
      ]) do

      add :name, :string, hash_key: true
    end
  end

  def down do
    alter table(:billing_mode_test,
      options: [
        global_indexes: [
          [index_name: "name",
            drop_if_exists: true]
        ]
      ]
    ) do
      remove :name
    end
  end

end
