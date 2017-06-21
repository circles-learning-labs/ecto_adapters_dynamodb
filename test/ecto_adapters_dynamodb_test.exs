defmodule Ecto.Adapters.DynamoDB.Test do
  use ExUnit.Case

  import Ecto.Query

  alias Ecto.Adapters.DynamoDB.TestRepo
  alias Ecto.Adapters.DynamoDB.TestSchema.Person

  @test_table "test_person"

  setup_all do
    TestHelper.setup_all(@test_table)
  end

  # A BASIC INSERT
  test "simple insert" do
    result = TestRepo.insert %Person {id: "person-hello", circles: nil, first_name: "Hello",
                                      last_name: "World", age: 34, email: "hello@world.com", password: "password"}
    assert result == {:ok, %Ecto.Adapters.DynamoDB.TestSchema.Person{age: 34, circles: nil, email: "hello@world.com",
                      first_name: "Hello", id: "person-hello", last_name: "World", password: "password",
                      __meta__: %Ecto.Schema.Metadata{context: nil, source: {nil, @test_table}, state: :loaded}}}
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
    person1 = %{id: "person-buster", circles: nil, first_name: "Buster", last_name: "Diavolo",
                age: 4, email: "buster@test.com", password: "password"}

    person2 = %{id: "person-pablo", circles: nil, first_name: "Pablo", last_name: "Martinez",
                age: 9, email: "pablo@test.com", password: "password"}

    result = TestRepo.insert_all(Person, [person1, person2])
    assert result == {2, nil}
  end

  # BATCH INSERT 1 RECORD
  test "simple insert_all: single-record" do
    person = %{id: "person-fred", circles: nil, first_name: "Fred", last_name: "Fly",
              age: 1, email: "fred@test.com", password: "password"}

    result = TestRepo.insert_all(Person, [person])
    assert result == {1, nil}
  end

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

  test "insert_all and query all: single condition, global secondary index" do
    person1 = %{id: "person-tomtest", circles: nil, first_name: "Tom", last_name: "Jones",
                age: 70, email: "jones@test.com", password: "password"}

    person2 = %{id: "person-caseytest", circles: nil, first_name: "Casey", last_name: "Jones",
                age: 114, email: "jones@test.com", password: "password"}

    person3 = %{id: "person-jamestest", circles: nil, first_name: "James", last_name: "Jones",
                age: 71, email: "jones@test.com", password: "password"}

    TestRepo.insert_all(Person, [person1, person2, person3])
    result = TestRepo.all(from p in Person, where: p.email == "jones@test.com")
    assert length(result) == 3
  end

  test "query all: multi condition, primary key/global secondary index" do
    TestRepo.insert(%Person{id: "person:jamesholden", first_name: "James", last_name: "Holden", email: "jholden@expanse.com"})
    result = TestRepo.all(from p in Person, where: p.id == "person:jamesholden", where: p.email == "jholden@expanse.com")
    assert Enum.at(result, 0).first_name == "James"
    assert Enum.at(result, 0).last_name == "Holden"
  end

  test "query all, filter out via is_nil" do
    person_lastname_nil = %Person{id: "person-frednil", first_name: "Fred",
                                  last_name: nil, email: "fred@frederson.fr"}
    person_lastname_notnil = %Person{id: "person-frednotnil", first_name: "Fred",
                                     last_name: "Frederson", email: "fred@frederson.fr"}

    TestRepo.insert person_lastname_nil
    TestRepo.insert person_lastname_notnil

    result = TestRepo.all(from p in Person,
                          where: p.email == "fred@frederson.fr", where: is_nil(p.last_name))
    assert result == [person_lastname_nil]
  end

  test "get not found" do
    result = TestRepo.get(Person, "person-faketestperson")
    assert result == nil
  end

  test "update field to nil" do
    person = %Person{id: "person:niltest", first_name: "LosingMy", last_name: "Account", email: "CloseThisAccount@test.com", age: 36}

    TestRepo.insert(person)
    res1 = TestRepo.get(Person, "person:niltest")
    assert res1.age == 36

    changeset = Person.changeset(res1, %{age: nil})
    TestRepo.update!(changeset)

    res2 = TestRepo.get(Person, "person:niltest")
    assert res2.age == nil
  end

  test "use delete_all to delete multiple records" do
    TestRepo.insert %Person{id: "person:delete_all_1", email: "delete_all@test.com"}
    TestRepo.insert %Person{id: "person:delete_all_2", email: "delete_all@test.com"}

    assert nil != TestRepo.get(Person, "person:delete_all_1")
    assert nil != TestRepo.get(Person, "person:delete_all_2")

    result = TestRepo.delete_all((from p in Person, where: p.email == "delete_all@test.com"), query_info_key: "delete_all:test_key")
    assert {2, nil} == result

    assert nil == TestRepo.get(Person, "person:delete_all_1")
    assert nil == TestRepo.get(Person, "person:delete_all_2")
  end
end
