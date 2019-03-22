defmodule Ecto.Adapters.DynamoDB.Migration.Test do
  @moduledoc """
  Unit tests for migrations.

  Test migrations will be tracked in the test_schema_migrations table (see config/test.exs)
  """
  # When the "down" tests are run at the end, suppress the "redefining modules" warnings.
  # https://stackoverflow.com/questions/36926388/how-can-i-avoid-the-warning-redefining-module-foo-when-running-exunit-tests-m
  Code.compiler_options(ignore_module_conflict: true)

  use ExUnit.Case
  alias Ecto.Adapters.DynamoDB.TestRepo

  @migration_path Path.expand("test/priv/test_repo/migrations")

  setup_all do
    TestHelper.setup_all(:migration)

    on_exit fn ->
      TestHelper.on_exit(:migration)
    end
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
      {:ok, table_info} = ExAws.Dynamo.describe_table("dog") |> ExAws.request

      [index] = table_info["Table"]["GlobalSecondaryIndexes"]

      assert length(result) == 1
      assert index["IndexName"] == "name"
      assert index["ProvisionedThroughput"]["ReadCapacityUnits"] == 0
      assert index["ProvisionedThroughput"]["WriteCapacityUnits"] == 0
    end

    test "alter table: add index to provisioned table" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      {:ok, table_info} = ExAws.Dynamo.describe_table("cat") |> ExAws.request

      [index] = table_info["Table"]["GlobalSecondaryIndexes"]

      assert length(result) == 1
      assert index["IndexName"] == "name"
      assert index["ProvisionedThroughput"]["ReadCapacityUnits"] == 2
      assert index["ProvisionedThroughput"]["WriteCapacityUnits"] == 1
    end

    test "create_if_not_exists: on-demand table with index" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      {:ok, table_info} = ExAws.Dynamo.describe_table("rabbit") |> ExAws.request

      [index] = table_info["Table"]["GlobalSecondaryIndexes"]

      assert length(result) == 1
      assert index["IndexName"] == "name"
      assert index["ProvisionedThroughput"]["ReadCapacityUnits"] == 0
      assert index["ProvisionedThroughput"]["WriteCapacityUnits"] == 0
    end

    test "alter table: modify index throughput" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      {:ok, table_info} = ExAws.Dynamo.describe_table("cat") |> ExAws.request

      [index] = table_info["Table"]["GlobalSecondaryIndexes"]

      assert length(result) == 1
      assert index["IndexName"] == "name"
      assert index["ProvisionedThroughput"]["ReadCapacityUnits"] == 3
      assert index["ProvisionedThroughput"]["WriteCapacityUnits"] == 2
    end
  end

  test "run migrations down" do
    {:ok, migrations} = File.ls(@migration_path)
    result = Ecto.Migrator.run(TestRepo, @migration_path, :down, all: true)
    assert length(result) == length(migrations)
  end

end
