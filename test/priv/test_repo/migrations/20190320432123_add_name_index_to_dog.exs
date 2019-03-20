defmodule Ecto.Adapters.DynamoDB.TestRepo.Migrations.AddNameIndexToDog do
  @moduledoc """
  Used when testing migrations.
  """
  use Ecto.Migration

  def up do
    alter table(:dog,
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
    alter table(:dog,
      options: [
        global_indexes: [
          [index_name: "name",
            drop_if_exists: true]]
      ]
    ) do
      remove :name
    end
  end

end
