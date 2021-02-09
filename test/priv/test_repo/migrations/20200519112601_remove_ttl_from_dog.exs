defmodule Ecto.Adapters.DynamoDB.TestRepo.Migrations.RemoveTTLFromDog do
  @moduledoc """
  Used when testing migrations.

  See the moduledoc for the previous migration for an explanation of this migration's purpose.
  """
  use Ecto.Migration

  def up do
    alter table(:dog,
            options: [
              ttl_attribute: nil
            ]
          ) do
      :ok
    end
  end

  def down do
    alter table(:dog,
            options: [
              ttl_attribute: "ttl"
            ]
          ) do
      :ok
    end
  end
end
