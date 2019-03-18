defmodule Ecto.Adapters.DynamoDB.Migration do
  use ExUnit.Case

  alias Ecto.Adapters.DynamoDB.TestRepo

  setup_all do
    on_exit fn ->
      TestHelper.on_exit()
    end
  end

  test "run migration" do
    Ecto.Migrator.run(TestRepo, [{0, EctoAdapters.DynamoDB.Test.Migrations.AddJookyTable}], :up, all: true)
  end

end
