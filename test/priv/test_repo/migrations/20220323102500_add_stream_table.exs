defmodule Ecto.Adapters.DynamoDB.TestRepo.Migrations.AddStreamTable do
  @moduledoc """
  Used when testing migrations.

  Create a table which has streaming enabled
  """
  use Ecto.Migration

  def up do
    create_if_not_exists table(:stream,
                           primary_key: false,
                           options: [
                             billing_mode: :pay_per_request,
                             stream_enabled: true,
                             stream_view_type: :keys_only
                           ]
                         ) do
      add(:id, :string, primary_key: true)

      timestamps()
    end
  end

  def down do
    drop_if_exists(table(:stream))
  end
end
