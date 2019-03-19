defmodule Ecto.Adapters.DynamoDB.TestRepo.Migrations.AddDogTable do
  @moduledoc """
  Used when testing migrations.
  """
  use Ecto.Migration

  def up do
    create_if_not_exists table(:dog,
      primary_key: false,
      options: [
        provisioned_throughput: [1,1]
      ]) do

      add :id, :string, primary_key: true

      timestamps()
    end
  end

  def down do
    drop_if_exists table(:dog)
  end

end
