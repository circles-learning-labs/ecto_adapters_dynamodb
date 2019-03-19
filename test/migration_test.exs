defmodule Ecto.Adapters.DynamoDB.Migration.Test do
  use ExUnit.Case

  alias Ecto.Adapters.DynamoDB.TestRepo

  setup_all do
    on_exit fn ->
      TestHelper.on_exit()
    end
  end

  # test "run migration" do
  #   path = Path.expand("test/priv/repo/migrations")

  #   Ecto.Migrator.run(TestRepo, path, :up, all: true)
  #   Ecto.Migrator.run(TestRepo, path, :down, all: true)
  # end

end
