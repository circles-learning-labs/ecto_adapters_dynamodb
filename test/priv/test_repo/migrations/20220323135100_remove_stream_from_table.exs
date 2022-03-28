defmodule Ecto.Adapters.DynamoDB.TestRepo.Migrations.RemoveStreamFromTable do
  @moduledoc """
  Used when testing migrations.

  Create a table which has streaming enabled
  """
  use Ecto.Migration

  def up do
    alter table(:stream,
            options: [
              stream_enabled: false
            ]
          ) do
    end
  end

  def down do
    alter table(:stream,
            options: [
              stream_enabled: true,
              stream_view_type: :keys_only
            ]
          ) do
    end
  end
end
