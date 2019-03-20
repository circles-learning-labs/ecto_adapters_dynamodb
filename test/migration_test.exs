defmodule Ecto.Adapters.DynamoDB.Migration.Test do
  @moduledoc """
  Unit tests for migrations.

  Test migrations will be tracked in the test_schema_migrations table (see config/test.exs)
  """
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
    test "create_if_not_exists: table" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      table_info = Ecto.Adapters.DynamoDB.Info.table_info("dog")

      assert length(result) == 1
      assert table_info["BillingModeSummary"]["BillingMode"] == "PAY_PER_REQUEST"
    end

    test "create: table" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      table_info = Ecto.Adapters.DynamoDB.Info.table_info("cat")


      assert length(result) == 1
      assert table_info["BillingModeSummary"]["BillingMode"] == "PROVISIONED"
    end

    test "update table: add index" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      {:ok, table_info} = ExAws.Dynamo.describe_table("dog") |> ExAws.request

      [index] = table_info["Table"]["GlobalSecondaryIndexes"]

      assert length(result) == 1
      assert index["IndexName"] == "name"
    end
  end

end
