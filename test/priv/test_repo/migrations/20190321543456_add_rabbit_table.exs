defmodule Ecto.Adapters.DynamoDB.TestRepo.Migrations.AddRabbitTable do
  @moduledoc """
  Used when testing migrations.

  Create a rabbit table with an index, set to pay_per_request (AKA on-demand) billing mode.
  """
  use Ecto.Migration

  def up do
    create_if_not_exists table(:rabbit,
      primary_key: false,
      options: [
        billing_mode: :pay_per_request,
        global_indexes: [
          [index_name: "name",
            keys: [:name]]
        ]
      ]) do

      add :id, :string, primary_key: true
      add :name, :string, hash_key: true

      timestamps()
    end
  end

  def down do
    drop_if_exists table(:rabbit)
  end

end
