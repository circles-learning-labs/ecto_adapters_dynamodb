defmodule Ecto.Adapters.DynamoDB.TestRepo.Migrations.AddStreamToCatTable do
  @moduledoc """
  Used when testing migrations.

  Create a table which has streaming enabled
  """
  use Ecto.Migration

  def up do
    alter table(:cat,
            options: [
              stream_enabled: true,
              stream_view_type: :new_image
            ]
          ) do
    end
  end

  def down do
    alter table(:cat,
            options: [
              stream_enabled: false
            ]
          ) do
    end
  end
end
