defmodule Ecto.Adapters.DynamoDB.Test do
  use ExUnit.Case

  alias Ecto.Adapters.DynamoDB.TestRepo
  alias Ecto.Adapters.DynamoDB.TestSchema.Person

  setup_all do
    IO.puts "starting test repo"
    TestRepo.start_link()
    :ok
  end

  # A BASIC GET
  test "simple get" do
    result = TestRepo.get(Person, "person-franko")
    assert result.first_name == "Franko"
    assert result.last_name == "Franicevich"
  end

  # A BASIC INSERT
  test "simple insert" do
    result = TestRepo.insert %Person {id: "person-hello", circles: nil, first_name: "Hello", last_name: "World", age: 34, email: "hello@world.com", password: "password"}
    assert result == {:ok, %Ecto.Adapters.DynamoDB.TestSchema.Person{age: 34, circles: nil, email: "hello@world.com", first_name: "Hello", id: "person-hello", last_name: "World", password: "password", __meta__: %Ecto.Schema.Metadata{context: nil, source: {nil, "person"}, state: :loaded}}}
  end

  # CREATE A RECORD AND THEN RETRIEVE IT - I.E. CREATE A NEW USER AND BE REDIRECTED TO THEIR PROFILE PAGE
  test "insert and get" do
    TestRepo.insert %Person {id: "person-john", circles: nil, first_name: "John", last_name: "Lennon", age: 40, email: "john@beatles.com", password: "password"}
    result = TestRepo.get(Person, "person-john")
    assert result.first_name == "John"
    assert result.last_name == "Lennon"
  end

  # BATCH INSERT 2 RECORDS
  test "simple insert_all: multi-record" do
    result = TestRepo.insert_all(Person, [%{id: "person-buster", circles: nil, first_name: "Buster", last_name: "Diavolo", age: 4, email: "buster@test.com", password: "password"}, %{id: "person-pablo", circles: nil, first_name: "Pablo", last_name: "Martinez", age: 9, email: "pablo@test.com", password: "password"}])
    assert result == {:ok, []}
  end

  # BATCH INSERT 1 RECORD
  test "simple insert_all: single-record" do
    result = TestRepo.insert_all(Person, [%{id: "person-fred", circles: nil, first_name: "Fred", last_name: "Fly", age: 1, email: "fred@test.com", password: "password"}])
    assert result == {:ok, []}
  end

  # SEE PLAT-54 - AWS/DYNAMO CAN'T HANDLE BULK INSERTS OF MORE THAN 25 ITEMS AT ONCE. WHEN WE IMPLEMENT A STRATEGY FOR THAT SCENARIO, WE CAN REOPEN THIS TEST.
  # test "simple insert_all: > 25" do
  #   result = TestRepo.insert_all(Person, [%{id: "person-multi-1", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_1@test.com", password: "password"}, %{id: "person-multi-2", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_2@test.com", password: "password"}, %{id: "person-multi-3", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_3@test.com", password: "password"}, %{id: "person-multi-4", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_4@test.com", password: "password"}, %{id: "person-multi-5", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_5@test.com", password: "password"}, %{id: "person-multi-6", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_6@test.com", password: "password"}, %{id: "person-multi-7", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_7@test.com", password: "password"}, %{id: "person-multi-8", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_8@test.com", password: "password"}, %{id: "person-multi-9", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_9@test.com", password: "password"}, %{id: "person-multi-10", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_10@test.com", password: "password"}, %{id: "person-multi-11", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_11@test.com", password: "password"}, %{id: "person-multi-12", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_12@test.com", password: "password"}, %{id: "person-multi-13", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_13@test.com", password: "password"}, %{id: "person-multi-14", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_14@test.com", password: "password"}, %{id: "person-multi-15", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_15@test.com", password: "password"}, %{id: "person-multi-16", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_16@test.com", password: "password"}, %{id: "person-multi-17", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_17@test.com", password: "password"}, %{id: "person-multi-18", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_18@test.com", password: "password"}, %{id: "person-multi-19", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_19@test.com", password: "password"}, %{id: "person-multi-20", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_20@test.com", password: "password"}, %{id: "person-multi-21", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_21@test.com", password: "password"}, %{id: "person-multi-22", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_22@test.com", password: "password"}, %{id: "person-multi-23", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_23@test.com", password: "password"}, %{id: "person-multi-24", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_24@test.com", password: "password"}, %{id: "person-multi-25", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_25@test.com", password: "password"}, %{id: "person-multi-26", circles: nil, first_name: "Multi", last_name: "Test", age: 1, email: "multi_26@test.com", password: "password"}])
  #   assert result == {:ok, []}
  # end

  # A RECORD IS CREATED, RETRIEVED, UPDATED, AND RETRIEVED AGAIN
  test "simple update" do
    TestRepo.insert %Person {id: "person-update", circles: nil, first_name: "Update", last_name: "Test", age: 12, email: "update@test.com", password: "password"}
    record_to_update = TestRepo.get(Person, "person-update")
    changeset = Ecto.Changeset.change record_to_update, [first_name: "Updated", last_name: "Tested"]
    TestRepo.update(changeset)
    result = TestRepo.get(Person, "person-update")
    assert result.first_name == "Updated"
    assert result.last_name == "Tested"
  end



  test "get not found" do
    result = TestRepo.get(Person, "person-faketestperson")
    assert result == nil
  end
end
