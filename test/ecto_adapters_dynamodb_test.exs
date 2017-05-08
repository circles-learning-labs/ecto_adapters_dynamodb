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

  test "simple insert" do
    result = TestRepo.insert %Person {id: "person-hello", circles: nil, first_name: "Hello", last_name: "World", age: 34, email: "hello@world.com", password: "password"}
    assert result == {:ok, %Ecto.Adapters.DynamoDB.TestSchema.Person{age: 34, circles: nil, email: "hello@world.com", first_name: "Hello", id: "person-hello", last_name: "World", password: "password", __meta__: %Ecto.Schema.Metadata{context: nil, source: {nil, "person"}, state: :loaded}}}
  end

  test "simple insert_all - multi-record" do
    result = TestRepo.insert_all(Person, [%{id: "person-buster", circles: nil, first_name: "Buster", last_name: "Diavolo", age: 4, email: "buster@test.com", password: "password"}, %{id: "person-pablo", circles: nil, first_name: "Pablo", last_name: "Martinez", age: 9, email: "pablo@test.com", password: "password"}])
    assert result == {:ok, []}
  end

  test "get not found" do
    result = TestRepo.get(Person, "person-faketestperson")
    assert result == nil
  end
end
