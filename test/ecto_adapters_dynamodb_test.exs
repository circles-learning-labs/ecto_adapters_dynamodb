defmodule Ecto.Adapters.DynamoDB.Test do
  use ExUnit.Case

  alias Ecto.Adapters.DynamoDB.TestRepo
  alias Ecto.Adapters.DynamoDB.TestSchema.Person

  setup_all do
    IO.puts "starting test repo"
    TestRepo.start_link()
    :ok
  end

  test "simple get" do
    result = TestRepo.get(Person, "person-franko")
    assert result.first_name == "Franko"
    assert result.last_name == "Franicevich"
  end

  test "get not found" do
    result = TestRepo.get(Person, "person-faketestperson")
    assert result == nil
  end
end
