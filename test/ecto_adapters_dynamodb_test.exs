defmodule Ecto.Adapters.DynamoDB.Test do
  use ExUnit.Case

  import Ecto.Query

  alias Ecto.Adapters.DynamoDB.TestRepo
  alias Ecto.Adapters.DynamoDB.TestSchema.Person
  alias Ecto.Adapters.DynamoDB.TestSchema.Address
  alias Ecto.Adapters.DynamoDB.TestSchema.BookPage

  @test_table "test_person"

  setup_all do
    TestHelper.setup_all()
  end

  # A basic insert
  test "simple insert" do
    result = TestRepo.insert %Person {id: "person-hello", circles: nil, first_name: "Hello",
                                      last_name: "World", age: 34, email: "hello@world.com", password: "password"}
    assert result == {:ok, %Ecto.Adapters.DynamoDB.TestSchema.Person{age: 34, circles: nil, email: "hello@world.com",
                      first_name: "Hello", id: "person-hello", last_name: "World", password: "password",
                      __meta__: %Ecto.Schema.Metadata{context: nil, source: {nil, @test_table}, state: :loaded}}}
  end

  # Create a record and then retrieve it
  test "insert and get" do
    TestRepo.insert %Person {id: "person-john", circles: nil, first_name: "John", last_name: "Lennon", age: 40, email: "john@beatles.com", password: "password", role: "musician"}
    result = TestRepo.get(Person, "person-john")
    assert result.first_name == "John"
    assert result.last_name == "Lennon"
  end

  test "insert and get with hash/range pkey" do
    name = "houseofleaves"

    page1 = %BookPage{id: name, page_num: 1, text: "abc"}
    page2 = %BookPage{id: name, page_num: 2, text: "def"}
    cs1 = BookPage.changeset(page1)
    cs2 = BookPage.changeset(page2)
    duplicate_page_cs = BookPage.changeset(%BookPage{id: name, page_num: 1, text: "ghi"})

    {:ok, _} = TestRepo.insert(cs1)
    {:ok, _} = TestRepo.insert(cs2)
    {:error, _} = TestRepo.insert(duplicate_page_cs)

    query = from p in BookPage, where: p.id == ^name
    results = query |> TestRepo.all |> Enum.sort_by(&(&1.page_num))
    IO.puts "results = #{inspect results}"

    [res1, res2] = results
    assert res1 == page1
    assert res2 == page2

    query1 = from p in BookPage, where: p.id == ^name and p.page_num == 1
    query2 = from p in BookPage, where: p.id == ^name and p.page_num == 2
    assert [page1] == TestRepo.all(query1)
    assert [page2] == TestRepo.all(query2)
  end

  test "primary key get/update/delete using query" do
    test_id = "person-pkey_query"
    test_person = %Person{id: test_id, circles: nil, first_name: "Albert", last_name: "Einstein", age: 76, email: "albert@einstein.com", password: "password"}
    query = from p in Person, where: p.id == ^test_id

    TestRepo.insert(test_person)
    [result] = TestRepo.all(query)
    assert result == test_person

    TestRepo.update_all(query, set: [circles: ["circle-fakecirc"]])
    [result] = TestRepo.all(query)
    assert result.circles == ["circle-fakecirc"]

    TestRepo.delete_all(query)
    assert [] == TestRepo.all(query)
  end

  # Batch insert two records
  test "simple insert_all: multi-record" do
    person1 = %{id: "person-buster", circles: nil, first_name: "Buster", last_name: "Diavolo",
                age: 4, email: "buster@test.com", password: "password"}

    person2 = %{id: "person-pablo", circles: nil, first_name: "Pablo", last_name: "Martinez",
                age: 9, email: "pablo@test.com", password: "password"}

    result = TestRepo.insert_all(Person, [person1, person2])
    assert result == {2, nil}
  end

  # Batch insert one record
  test "simple insert_all: single-record" do
    person = %{id: "person-fred", circles: nil, first_name: "Fred", last_name: "Fly",
              age: 1, email: "fred@test.com", password: "password"}

    result = TestRepo.insert_all(Person, [person])
    assert result == {1, nil}
  end

  # Batch insert 55 records
  # DynamoDB has a constraint on the call to BatchWriteItem, where attempts to insert more than
  # 25 records will be rejected. We allow the user to call insert_all() for more than 25 records
  # by breaking up the requests into blocks of 25.
  # https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_BatchWriteItem.html
  test "simple insert_all: exceed BatchWriteItem limit by 20 records" do
    total_inserts = 55
    people = for i <- 0..total_inserts, i > 0 do
               id_string = :crypto.strong_rand_bytes(16) |> Base.url_encode64 |> binary_part(0, 16)
               id = "person:" <> id_string

               %{id: id, circles: nil, first_name: "Batch",
                 last_name: "Insert", age: i, email: "batch_insert#{i}@test.com", password: "password"}
             end

    result = TestRepo.insert_all(Person, people)
    assert result == {total_inserts, nil}
  end

  # A record is created, retrieved, updated, and retrieved again.
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

  test "embedded records" do
    key = "person:address_test"
    addr_list = [%Address{street_number: 245, street_name: "W 17th St"},
                 %Address{street_number: 1385, street_name: "Broadway"}]
    rec = %Person{id: key, email: "addr@test.com", addresses: addr_list}
    {:ok, inserted} = TestRepo.insert(rec)

    result = TestRepo.get(Person, key)

    # Remove the metadata to allow for a direct comparison:
    inserted = Map.delete(inserted, :__meta__)
    result = Map.delete(result, :__meta__)
    assert result == inserted
  end

  test "batch_get multiple records - hard-coded list" do
    person1 = %{id: "person-jimi", circles: nil, first_name: "Jimi", last_name: "Hendrix",
                age: 27, email: "jimi@hendrix.com", password: "password"}
    person2 = %{id: "person-noel", circles: nil, first_name: "Noel", last_name: "Redding",
                age: 72, email: "noel@redding.com", password: "password"}
    person3 = %{id: "person-mitch", circles: nil, first_name: "Mitch", last_name: "Mitchell",
                age: 74, email: "mitch@mitchell.com", password: "password"}

    TestRepo.insert_all(Person, [person1, person2, person3])

    result = TestRepo.all(from p in Person, where: p.id in ["person-jimi", "person-noel", "person-mitch"])
             |> Enum.map(&(&1.id))

    assert Enum.sort(result) == Enum.sort(["person-jimi", "person-noel", "person-mitch"])
  end

  # batch_get operations with interpolated lists are handled slightly differently than those with hard-coded lists
  test "batch_get multiple records - interpolated list" do
    person1 = %{id: "person-moe", circles: nil, first_name: "Moe", last_name: "Howard",
                age: 75, email: "moe@stooges.com", password: "password"}
    person2 = %{id: "person-larry", circles: nil, first_name: "Larry", last_name: "Fine",
                age: 72, email: "larry@stooges.com", password: "password"}
    person3 = %{id: "person-curly", circles: nil, first_name: "Curly", last_name: "Howard",
                age: 74, email: "curly@stooges.com", password: "password"}

    TestRepo.insert_all(Person, [person1, person2, person3])

    person_ids = [person1.id, person2.id, person3.id]
    result = TestRepo.all(from p in Person, where: p.id in ^person_ids)
             |> Enum.map(&(&1.id))

    assert Enum.sort(result) == Enum.sort(person_ids)
  end

end
