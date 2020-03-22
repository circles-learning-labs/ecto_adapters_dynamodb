defmodule Ecto.Adapters.DynamoDB.Migration.Test do
  @moduledoc """
  Unit tests for migrations.

  Test migrations will be tracked in the test_schema_migrations table (see config/test.exs)

  Note that migration tests must be run in order, so in test_helper.exs, we use the command `ExUnit.start(seed: 0)`

  The order of tests in this file MUST match the order of execution of the files in test/priv/test_repo/migrations
  """

  # When the "down" tests are run at the end, suppress the "redefining modules" warnings.
  # https://stackoverflow.com/questions/36926388/how-can-i-avoid-the-warning-redefining-module-foo-when-running-exunit-tests-m
  Code.compiler_options(ignore_module_conflict: true)

  use ExUnit.Case

  alias Ecto.Adapters.DynamoDB.TestRepo

  @migration_path Path.expand("test/priv/test_repo/migrations")

  setup_all do
    TestHelper.setup_all(:migration)

    on_exit(fn ->
      TestHelper.on_exit(:migration)
    end)
  end

  describe "execute_ddl" do
    test "create_if_not_exists: on-demand table" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      table_info = Ecto.Adapters.DynamoDB.Info.table_info("dog")

      assert length(result) == 1
      assert table_info["BillingModeSummary"]["BillingMode"] == "PAY_PER_REQUEST"
    end

    test "create: provisioned table" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      table_info = Ecto.Adapters.DynamoDB.Info.table_info("cat")

      assert length(result) == 1
      assert table_info["BillingModeSummary"]["BillingMode"] == "PROVISIONED"
    end

    test "alter table: add index to on-demand table" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      {:ok, table_info} = ExAws.Dynamo.describe_table("dog") |> ExAws.request()
      [index] = table_info["Table"]["GlobalSecondaryIndexes"]

      assert length(result) == 1
      assert index["IndexName"] == "name"
      assert index["ProvisionedThroughput"]["ReadCapacityUnits"] == 0
      assert index["ProvisionedThroughput"]["WriteCapacityUnits"] == 0
    end

    test "alter table: add index to provisioned table" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      {:ok, table_info} = ExAws.Dynamo.describe_table("cat") |> ExAws.request()
      [index] = table_info["Table"]["GlobalSecondaryIndexes"]

      assert length(result) == 1
      assert index["IndexName"] == "name"
      assert index["ProvisionedThroughput"]["ReadCapacityUnits"] == 2
      assert index["ProvisionedThroughput"]["WriteCapacityUnits"] == 1
    end

    test "create_if_not_exists: on-demand table with index" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      {:ok, table_info} = ExAws.Dynamo.describe_table("rabbit") |> ExAws.request()
      [foo_index, name_index] = table_info["Table"]["GlobalSecondaryIndexes"]

      assert length(result) == 1
      assert name_index["IndexName"] == "name"
      assert name_index["ProvisionedThroughput"]["ReadCapacityUnits"] == 0
      assert name_index["ProvisionedThroughput"]["WriteCapacityUnits"] == 0
      assert foo_index["IndexName"] == "foo"
      assert foo_index["ProvisionedThroughput"]["ReadCapacityUnits"] == 0
      assert foo_index["ProvisionedThroughput"]["WriteCapacityUnits"] == 0
    end

    test "alter table: modify index throughput" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      {:ok, table_info} = ExAws.Dynamo.describe_table("cat") |> ExAws.request()
      [index] = table_info["Table"]["GlobalSecondaryIndexes"]

      assert length(result) == 1
      assert index["IndexName"] == "name"
      assert index["ProvisionedThroughput"]["ReadCapacityUnits"] == 3
      assert index["ProvisionedThroughput"]["WriteCapacityUnits"] == 2
    end

    test "alter table: attempt to add an index that already exists" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      {:ok, table_info} = ExAws.Dynamo.describe_table("cat") |> ExAws.request()
      [index] = table_info["Table"]["GlobalSecondaryIndexes"]

      assert length(result) == 1
      assert index["IndexName"] == "name"
      # If the migration is successful, the throughput specified by the preceding migration will not have been altered.
      assert index["ProvisionedThroughput"]["ReadCapacityUnits"] == 3
      assert index["ProvisionedThroughput"]["WriteCapacityUnits"] == 2
    end
  end

  describe "execute_ddl - local vs. production discrepancies" do
    # In the pair of migrations in this test, we create a provisioned table and then attempt to add an index with no specified throughput, as you would for an on-demand table.
    # This is meant to replicate a scenario where a provisioned table is set to on-demand via the AWS dashboard...
    # some time later, a developer writes a migration to add an index to the (now on-demand) table in production, but her local table is still provisioned.
    # The index migration will not specify provisioned_throughput, but this will fail locally - the dev version of DDB will just hang rather than raising an error.
    # When Mix.env is :dev or :test, we'll need to quietly add provisioned_throughput to the index so that the migration can be run.
    # The logic associated with this can be found in lib/migration.ex, under the private method maybe_default_throughput/3.
    test "create_if_not_exists and alter table: add an index to a table where the billing mode has been manually changed to on-demand in production" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 2)

      assert length(result) == 2
    end
  end

  test "run migrations down" do
    {:ok, migrations} = File.ls(@migration_path)
    result = Ecto.Migrator.run(TestRepo, @migration_path, :down, all: true)
    assert length(result) == length(migrations)
  end
end
