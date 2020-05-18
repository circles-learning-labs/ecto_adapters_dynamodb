defmodule Ecto.Adapters.DynamoDB.TestRepo.Migrations.ModifyCatNameIndex do
  @moduledoc """
  Used when testing migrations.

  Modify the throughput on the name index for the cat table.
  """
  use Ecto.Migration

  def up do
    alter table(:cat) do
      modify(:name, :string, provisioned_throughput: [3, 2])
    end
  end

  def down do
    alter table(:cat) do
      modify(:name, :string, provisioned_throughput: [2, 1])
    end
  end
end
