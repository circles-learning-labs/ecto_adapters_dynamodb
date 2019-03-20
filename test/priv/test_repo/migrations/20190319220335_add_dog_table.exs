defmodule Ecto.Adapters.DynamoDB.TestRepo.Migrations.AddDogTable do
  @moduledoc """
  Used when testing migrations.

  Create a dog table, set to pay_per_request (AKA on-demand) billing mode.
  """
  use Ecto.Migration

  def up do
    create_if_not_exists table(:dog,
      primary_key: false,
      options: [
        billing_mode: :pay_per_request
      ]) do

      add :id, :string, primary_key: true

      timestamps()
    end
  end

  def down do
    drop_if_exists table(:dog)
  end

end
