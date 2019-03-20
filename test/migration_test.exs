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
    test "create tables" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 2)

      dog_info = Ecto.Adapters.DynamoDB.Info.table_info("dog")
      cat_info = Ecto.Adapters.DynamoDB.Info.table_info("cat")

      assert length(result) == 2
      assert dog_info["BillingModeSummary"]["BillingMode"] == "PAY_PER_REQUEST"
      assert cat_info["BillingModeSummary"]["BillingMode"] == "PROVISIONED"
    end
  end

end
