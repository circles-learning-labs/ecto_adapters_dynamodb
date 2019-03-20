defmodule Ecto.Adapters.DynamoDB.TestRepo.Migrations.AddCatTable do
  @moduledoc """
  Used when testing migrations.

  Create a cat table, set to provisioned billing mode.
  """
  use Ecto.Migration

  def up do
    create table(:cat,
      primary_key: false,
      options: [
        provisioned_throughput: [1,1]
      ]) do

      add :id, :string, primary_key: true

      timestamps()
    end
  end

  def down do
    drop table(:cat)
  end

end
