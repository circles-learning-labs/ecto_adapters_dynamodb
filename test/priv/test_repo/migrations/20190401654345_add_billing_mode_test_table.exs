defmodule Ecto.Adapters.DynamoDB.TestRepo.Migrations.AddBillingModeTestTable do
  @moduledoc """
  Used when testing migrations.

  Create a billing_mode_test table. This will be used with the following migration to test a particular scenario...

  A table's billing mode (on-demand or provisioned) can be set either through migrations or through the AWS dashboard;
  it's possible to have a scenario where a developer would create a provisioned table via migration which an admin
  then flips to pay_per_request via the dashboard. The dev may then create a migration to add an index to that table,
  which is now on-demand in production but provisioned locally; the migration would lack a specified provisioned throughput,
  which would work in production but would fail locally.

  This migration and the following one aim to replicate such a scenario - the table is created as provisioned, but the index does not specify a provisioned throughput.

  In production, this kind of discrepancy produces one of the following errors, depending on the disagreement:

    (ExAws.Error) ExAws Request Error! {"ValidationException", "One or more parameter values were invalid: Both ReadCapacityUnits and WriteCapacityUnits must be specified for index: name"}

    (ExAws.Error) ExAws Request Error! {"ValidationException", "One or more parameter values were invalid: Neither ReadCapacityUnits nor WriteCapacityUnits can be specified for index: name when BillingMode is PAY_PER_REQUEST"}

  However, in local development, the first error won't be thrown, the migration will just hang until it times out;
  the second won't occur at all, local dev DDB will just ignore any specified provisioned throughput.

  The logic associated with this can be found in lib/migration.ex, under the private method maybe_default_throughput/3.
  """
  use Ecto.Migration

  def up do
    create_if_not_exists table(:billing_mode_test,
                           primary_key: false,
                           options: [
                             provisioned_throughput: [1, 1]
                           ]
                         ) do
      add(:id, :string, primary_key: true)

      timestamps()
    end
  end

  def down do
    drop_if_exists(table(:billing_mode_test))
  end
end
