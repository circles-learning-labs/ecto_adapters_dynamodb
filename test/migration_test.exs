defmodule Ecto.Adapters.DynamoDB.Migration.Test do
  @moduledoc """
  Unit tests for migrations.

  Test migrations will be tracked in the test_schema_migrations table (see config/test.exs)
  """
  use ExUnit.Case

  alias Ecto.Adapters.DynamoDB.TestRepo

  @migration_path Path.expand("test/priv/repo/migrations")

  setup_all do
    TestHelper.setup_all(:migration)

    on_exit fn ->
      TestHelper.on_exit(:migration)
    end
  end

  describe "execute_ddl" do
    # This migration will create the dog table
    test "create_if_not_exists: table" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      assert length(result) == 1
    end

    # This migration will create the cat table
    test "create: table" do
      result = Ecto.Migrator.run(TestRepo, @migration_path, :up, step: 1)
      assert length(result) == 1
    end
  end

end
