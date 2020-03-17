defmodule Ecto.Adapters.DynamoDB.Test do
  @moduledoc """
  Unit tests for the adapter's main public API.
  """

  use ExUnit.Case

  import Ecto.Query

  alias Ecto.Adapters.DynamoDB.TestRepo
  alias Ecto.Adapters.DynamoDB.TestSchema.{Person, Address, BookPage, Planet}

  setup_all do
    TestHelper.setup_all()

    on_exit(fn ->
      TestHelper.on_exit()
    end)
  end


  test "Repo.get/2 - no matching record" do
    result = TestRepo.get(Person, "person-faketestperson")
    assert result == nil
  end

  describe "insert and get" do
    test "insert and get - embedded records, source-mapped field" do
      {:ok, insert_result} = TestRepo.insert(%Person{
                          id: "person:address_test",
                          first_name: "Ringo",
                          last_name: "Starr",
                          email: "ringo@test.com",
                          age: 76,
                          country: "England",
                          addresses: [
                             %Address{
                               street_number: 245,
                               street_name: "W 17th St"
                             },
                             %Address{
                               street_number: 1385,
                               street_name: "Broadway"
                             }
                           ]
                        })

      assert length(insert_result.addresses) == 2
      assert get_datetime_type(insert_result.inserted_at) == :naive_datetime_usec
      assert get_datetime_type((insert_result.addresses |> Enum.at(0)).updated_at) == :utc_datetime
      assert insert_result.country == "England"
      assert insert_result.__meta__ == %Ecto.Schema.Metadata{
                                          state: :loaded,
                                          source: "test_person",
                                          schema: Person
                                        }

      get_result = TestRepo.get(Person, insert_result.id)
      assert get_result == insert_result
    end
  end

  # describe "Repo.get/2" do
  #   # This doesn't belong in Repo.get testing, it belongs in query testing.
  #   test "insert a record and get with a hash/range pkey" do
  #     name = "houseofleaves"
  #     page1 = %BookPage{
  #               id: name,
  #               page_num: 1,
  #               text: "abc",
  #             }
  #     page2 = %BookPage{
  #               id: name,
  #               page_num: 2,
  #               text: "def",
  #             }
  #     cs1 = BookPage.changeset(page1)
  #     cs2 = BookPage.changeset(page2)
  #     duplicate_page_cs = BookPage.changeset(%BookPage{
  #                                              id: name,
  #                                              page_num: 1,
  #                                              text: "ghi",
  #                                            })

  #     {:ok, page1} = TestRepo.insert(cs1)
  #     {:ok, page2} = TestRepo.insert(cs2)
  #     {:error, _} = TestRepo.insert(duplicate_page_cs)

  #     query = from p in BookPage, where: p.id == ^name
  #     results = query |> TestRepo.all |> Enum.sort_by(&(&1.page_num))
  #     [res1, res2] = results

  #     assert res1 == page1
  #     assert res2 == page2

  #     query1 = from p in BookPage, where: p.id == ^name and p.page_num == 1
  #     query2 = from p in BookPage, where: p.id == ^name and p.page_num == 2

  #     assert [page1] == TestRepo.all(query1)
  #     assert [page2] == TestRepo.all(query2)
  #   end
  # end

  # describe "Repo.insert_all/2" do
  #   test "batch-insert single and multiple records" do
  #     # single
  #     total_records = 1
  #     people = make_list_of_people_for_batch_insert(total_records)
  #     result = TestRepo.insert_all(Person, people)

  #     assert result == {total_records, nil}

  #     # multiple
  #     total_records = 5
  #     people = make_list_of_people_for_batch_insert(total_records)
  #     result = TestRepo.insert_all(Person, people)

  #     assert result == {total_records, nil}
  #   end

  #   # DynamoDB has a constraint on the call to BatchWriteItem, where attempts to insert more than
  #   # 25 records will be rejected. We allow the user to call insert_all() for more than 25 records
  #   # by breaking up the requests into blocks of 25.
  #   # https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_BatchWriteItem.html
  #   test "batch-insert multiple records, exceeding BatchWriteItem limit by 30 records" do
  #     total_records = 55
  #     people = make_list_of_people_for_batch_insert(total_records)
  #     result = TestRepo.insert_all(Person, people)

  #     assert result == {total_records, nil}
  #   end
  # end

  # describe "Repo.all" do
  #   test "batch-get multiple records when querying for an empty list" do
  #     result = TestRepo.all(from p in Person, where: p.id in [])
  #     assert result == []
  #   end

  #   test "batch-get multiple records with an 'all... in...' query when querying for a hard-coded and a variable list of primary hash keys" do
  #     person1 = %{
  #                 id: "person-moe",
  #                 first_name: "Moe",
  #                 last_name: "Howard",
  #                 age: 75,
  #                 email: "moe@stooges.com",
  #                 password: "password",
  #               }
  #     person2 = %{
  #                 id: "person-larry",
  #                 first_name: "Larry",
  #                 last_name: "Fine",
  #                 age: 72,
  #                 email: "larry@stooges.com",
  #                 password: "password",
  #               }
  #     person3 = %{
  #                 id: "person-curly",
  #                 first_name: "Curly",
  #                 last_name: "Howard",
  #                 age: 74,
  #                 email: "curly@stooges.com",
  #                 password: "password",
  #               }

  #     TestRepo.insert_all(Person, [person1, person2, person3])

  #     ids = [person1.id, person2.id, person3.id]
  #     sorted_ids = Enum.sort(ids)

  #     var_result =
  #       TestRepo.all(from p in Person,
  #         where: p.id in ^ids,
  #         select: p.id)
  #       |> Enum.sort()
  #     hc_result =
  #       TestRepo.all(from p in Person,
  #         where: p.id in ["person-moe", "person-larry", "person-curly"],
  #         select: p.id)
  #       |> Enum.sort()

  #     assert var_result == sorted_ids
  #     assert hc_result == sorted_ids
  #   end

  #   test "batch-get multiple records with an 'all... in...' query when querying for a hard-coded and a variable lists of composite primary keys" do
  #     page1 = %{
  #               id: "page:test-1",
  #               page_num: 1,
  #               text: "abc",
  #             }
  #     page2 = %{
  #               id: "page:test-2",
  #               page_num: 2,
  #               text: "def",
  #             }

  #     TestRepo.insert_all(BookPage, [page1, page2])
  #     ids = [page1.id, page2.id]
  #     pages = [1, 2]

  #     var_result = TestRepo.all(from bp in BookPage, where: bp.id in ^ids and bp.page_num in ^pages)
  #                  |> Enum.map(&(&1.id))
  #                  |> Enum.sort()
  #     hc_result = TestRepo.all(from bp in BookPage, where: bp.id in ["page:test-1", "page:test-2"] and bp.page_num in [1, 2])
  #                 |> Enum.map(&(&1.id))
  #                 |> Enum.sort()

  #     sorted_ids = Enum.sort(ids)

  #     assert var_result == sorted_ids
  #     assert hc_result == sorted_ids
  #   end

  #   test "batch-get multiple records with an 'all... in...' query on a hash key-only global secondary index when querying for a hard-coded and variable list" do
  #     person1 = %{
  #       id: "person-jerrytest",
  #       first_name: "Jerry",
  #       last_name: "Garcia",
  #       age: 55,
  #       email: "jerry@test.com",
  #       password: "password",
  #     } 
  #     person2 = %{
  #       id: "person-bobtest",
  #       first_name: "Bob",
  #       last_name: "Weir",
  #       age: 70,
  #       email: "bob@test.com",
  #       password: "password"
  #     }

  #     TestRepo.insert_all(Person, [person1, person2])

  #     emails = [person1.email, person2.email]
  #     sorted_ids = Enum.sort([person1.id, person2.id])
  #     var_result = TestRepo.all(from p in Person, where: p.email in ^emails)
  #                  |> Enum.map(&(&1.id))
  #                  |> Enum.sort()
  #     hc_result = TestRepo.all(from p in Person, where: p.email in ["jerry@test.com", "bob@test.com"])
  #                 |> Enum.map(&(&1.id))
  #                 |> Enum.sort()

  #     assert var_result == sorted_ids
  #     assert hc_result == sorted_ids

  #     [var_multi_cond_result] = TestRepo.all(from p in Person, where: p.email in ^emails and p.age > 69)
  #     [hc_multi_cond_result] = TestRepo.all(from p in Person, where: p.email in ["jerry@test.com", "bob@test.com"] and p.age < 69)

  #     assert var_multi_cond_result.id == "person-bobtest"
  #     assert hc_multi_cond_result.id == "person-jerrytest"
  #   end

  #   test "batch-get multiple records with an 'all... in...' query on a composite global secondary index (hash and range keys) when querying for a hard-coded and variable list" do
  #     person1 = %{
  #       id: "person:frank",
  #       first_name: "Frank",
  #       last_name: "Sinatra",
  #       age: 45,
  #       email: "frank_sinatra@test.com",
  #     } 
  #     person2 = %{
  #       id: "person:dean",
  #       first_name: "Dean",
  #       last_name: "Martin",
  #       age: 70,
  #       email: "dean_martin@test.com",
  #     }

  #     TestRepo.insert_all(Person, [person1, person2])

  #     first_names = [person1.first_name, person2.first_name]
  #     sorted_ids = Enum.sort([person1.id, person2.id])
  #     var_result = TestRepo.all(from p in Person, where: p.first_name in ^first_names and p.age < 50)
  #                  |> Enum.map(&(&1.id))
  #     hc_result = TestRepo.all(from p in Person, where: p.first_name in ["Frank", "Dean"] and p.age > 40)
  #                 |> Enum.map(&(&1.id))
  #                 |> Enum.sort()

  #     assert var_result == ["person:frank"]
  #     assert hc_result == sorted_ids
  #   end

  #   test "batch-get multiple records on a partial secondary index composite key (hash only)" do
  #     person1 = %{
  #       id: "person:wayne_shorter",
  #       first_name: "Wayne",
  #       last_name: "Shorter",
  #       age: 75,
  #       email: "wayne_shorter@test.com",
  #     }
  #     person2 = %{
  #       id: "person:wayne_campbell",
  #       first_name: "Wayne",
  #       last_name: "Campbell",
  #       age: 36,
  #       email: "wayne_campbell@test.com"
  #     }

  #     TestRepo.insert_all(Person, [person1, person2])

  #     sorted_ids = Enum.sort([person1.id, person2.id])
  #     result = TestRepo.all(from p in Person, where: p.first_name == "Wayne")
  #              |> Enum.map(&(&1.id))
  #              |> Enum.sort()

  #     assert result == sorted_ids
  #   end

  #   # DynamoDB has a constraint on the call to BatchGetItem, where attempts to retrieve more than
  #   # 100 records will be rejected. We allow the user to call all() for more than 100 records
  #   # by breaking up the requests into blocks of 100.
  #   # https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_BatchGetItem.html
  #   test "batch-get multiple records, exceeding BatchGetItem limit by 10 records" do
  #     total_records = 110
  #     people_to_insert = make_list_of_people_for_batch_insert(total_records) # create a list of people records
  #     person_ids = for person <- people_to_insert, do: person.id # hang on to the ids separately

  #     TestRepo.insert_all(Person, people_to_insert)
  #     result = TestRepo.all(from p in Person, where: p.id in ^person_ids)
  #              |> Enum.map(&(&1.id))

  #     assert length(result) == total_records
  #   end

  #   test "batch-insert and query all on a hash key global secondary index" do
  #     person1 = %{
  #                 id: "person-tomtest",
  #                 first_name: "Tom",
  #                 last_name: "Jones",
  #                 age: 70,
  #                 email: "jones@test.com",
  #                 password: "password",
  #               }
  #     person2 = %{
  #                 id: "person-caseytest",
  #                 first_name: "Casey",
  #                 last_name: "Jones",
  #                 age: 114,
  #                 email: "jones@test.com",
  #                 password: "password",
  #               }
  #     person3 = %{
  #                 id: "person-jamestest",
  #                 first_name: "James",
  #                 last_name: "Jones",
  #                 age: 71,
  #                 email: "jones@test.com",
  #                 password: "password",
  #               }

  #     TestRepo.insert_all(Person, [person1, person2, person3])
  #     result = TestRepo.all(from p in Person, where: p.email == "jones@test.com")

  #     assert length(result) == 3
  #   end

  #   test "query all on a multi-condition primary key/global secondary index" do
  #     TestRepo.insert(%Person{
  #                       id: "person:jamesholden",
  #                       first_name: "James",
  #                       last_name: "Holden",
  #                       age: 18,
  #                       email: "jholden@expanse.com",
  #                     })
  #     result = TestRepo.all(from p in Person, where: p.id == "person:jamesholden" and p.email == "jholden@expanse.com")

  #     assert Enum.at(result, 0).first_name == "James"
  #     assert Enum.at(result, 0).last_name == "Holden"
  #   end

  #   test "query all on a composite primary key, using a 'begins_with' fragment on the range key" do
  #     planet1 = %{
  #       id: "planet",
  #       name: "Jupiter",
  #       mass: 6537292902,
  #       moons: MapSet.new(["Io", "Europa", "Ganymede"])
  #     }
  #     planet2 = %{
  #       id: "planet",
  #       name: "Pluto",
  #       mass: 3465,
  #     }

  #     TestRepo.insert_all(Planet, [planet1, planet2])
  #     name_frag = "J"

  #     q = from(p in Planet, where: p.id == "planet" and fragment("begins_with(?, ?)", p.name, ^name_frag))

  #     result = TestRepo.all(q)

  #     assert length(result) == 1
  #   end

  #   test "query all on a partial primary composite index using 'in' and '==' operations" do
  #     planet1 = %{
  #       id: "planet-earth",
  #       name: "Earth",
  #       mass: 476,
  #     }
  #     planet2 = %{
  #       id: "planet-mars",
  #       name: "Mars",
  #       mass: 425,
  #     }

  #     TestRepo.insert_all(Planet, [planet1, planet2])
  #     ids = ["planet-earth", "planet-mars"]
  #     in_q = from(p in Planet, where: p.id in ^ids)
  #     equals_q = from(p in Planet, where: p.id == "planet-earth")
  #     in_result = TestRepo.all(in_q)
  #     equals_result = TestRepo.all(equals_q)

  #     assert length(in_result) == 2
  #     assert length(equals_result) == 1
  #   end

  #   test "query all on a partial secondary index using 'in' and '==' operations" do
  #     planet1 = %{
  #       id: "planet-mercury",
  #       name: "Mercury",
  #       mass: 153,
  #     }
  #     planet2 = %{
  #       id: "planet-saturn",
  #       name: "Saturn",
  #       mass: 409282891,
  #     }

  #     TestRepo.insert_all(Planet, [planet1, planet2])
  #     in_q = from(p in Planet, where: p.name in ["Mercury", "Saturn"])
  #     equals_q = from(p in Planet, where: p.name == "Mercury")
  #     in_result = TestRepo.all(in_q)
  #     equals_result = TestRepo.all(equals_q)

  #     assert length(in_result) == 2
  #     assert length(equals_result) == 1
  #   end

  #   test "query all on global secondary index with a composite key, using a 'begins_with' fragment on the range key" do
  #     person1 = %{
  #                 id: "person-michael-jordan",
  #                 first_name: "Michael",
  #                 last_name: "Jordan",
  #                 age: 52,
  #                 email: "mjordan@test.com",
  #                 password: "password",
  #               }
  #     person2 = %{
  #                 id: "person-michael-macdonald",
  #                 first_name: "Michael",
  #                 last_name: "MacDonald",
  #                 age: 74,
  #                 email: "singin_dude@test.com",
  #                 password: "password",
  #               }

  #     TestRepo.insert_all(Person, [person1, person2])
  #     email_frag = "m"
  #     q = from(p in Person, where: p.first_name == "Michael" and fragment("begins_with(?, ?)", p.email, ^email_frag))

  #     result = TestRepo.all(q)

  #     assert length(result) == 1
  #   end

  #   test "query all on a global secondary index where an :index option has been provided to resolve an ambiguous index choice" do
  #     person1 = %{
  #                 id: "person-methuselah-baby",
  #                 first_name: "Methuselah",
  #                 last_name: "Baby",
  #                 age: 0,
  #                 email: "newborn_baby@test.com",
  #                 password: "password",
  #               }
  #     person2 = %{
  #                 id: "person-methuselah-jones",
  #                 first_name: "Methuselah",
  #                 last_name: "Jones",
  #                 age: 969,
  #                 email: "methuselah@test.com",
  #                 password: "password",
  #               }

  #     TestRepo.insert_all(Person, [person1, person2])

  #     q = from(p in Person, where: p.first_name == "Methuselah" and p.age in [0, 969])
  #     # based on the query, it won't be clear to the adapter whether to choose the first_name_age or age_first_name index - pass the :index option to make sure it queries correctly.
  #     result = TestRepo.all(q, index: "age_first_name")

  #     assert length(result) == 2
  #   end
  # end

  # describe "Repo.update/1" do
  #   test "update two fields on a record" do
  #     TestRepo.insert(%Person{
  #                       id: "person-update",
  #                       first_name: "Update",
  #                       last_name: "Test",
  #                       age: 12,
  #                       email: "update@test.com",
  #                       password: "password",
  #                     })
  #     {:ok, result} = TestRepo.get(Person, "person-update")
  #                     |> Ecto.Changeset.change([first_name: "Updated", last_name: "Tested"])
  #                     |> TestRepo.update()

  #     assert result.first_name == "Updated"
  #     assert result.last_name == "Tested"
  #   end
  # end

  # describe "Repo.update_all/3" do
  #   test "update fields on multiple records based on a primary hash key query" do
  #     person1 = %{
  #                 id: "person-george",
  #                 first_name: "George",
  #                 last_name: "Washington",
  #                 age: 70,
  #                 email: "george@washington.com",
  #                 password: "password",
  #               }
  #     person2 = %{
  #                 id: "person-thomas",
  #                 first_name: "Thomas",
  #                 last_name: "Jefferson",
  #                 age: 27,
  #                 email: "thomas@jefferson.com",
  #                 password: "password",
  #               }
  #     person3 = %{
  #                 id: "person-warren",
  #                 first_name: "Warren",
  #                 last_name: "Harding",
  #                 age: 71,
  #                 email: "warren@harding.com",
  #                 password: "password",
  #               }

  #     ids = [person1.id, person2.id, person3.id]
  #     TestRepo.insert_all(Person, [person1, person2, person3])

  #     # Note that we test queries with both hard-coded and variable lists, as these are handled differently.
  #     hc_query = from p in Person, where: p.id in ["person-george", "person-thomas", "person-warren"]
  #     var_query = from p in Person, where: p.id in ^ids

  #     TestRepo.update_all(hc_query, set: [last_name: nil])
  #     TestRepo.update_all(var_query, set: [password: nil])

  #     result = TestRepo.all(from p in Person, where: p.id in ^ids)
  #              |> Enum.map(fn(item) -> [item.last_name, item.password] end)

  #     assert result == [[nil, nil], [nil, nil], [nil, nil]]

  #     TestRepo.update_all(hc_query, set: [first_name: "Joey", age: 12])
  #     TestRepo.update_all(var_query, set: [password: "cheese", last_name: "Smith"])

  #     result = TestRepo.all(from p in Person, where: p.id in ^ids)
  #              |> Enum.map(fn(item) -> [item.first_name, item.last_name, item.age, item.password] end)

  #     assert result == [["Joey", "Smith", 12, "cheese"], ["Joey", "Smith", 12, "cheese"], ["Joey", "Smith", 12, "cheese"]]
  #   end

  #   test "update fields on multiple records based on a primary composite key query" do
  #     page1 = %{
  #               id: "page:test-3",
  #               page_num: 1,
  #               text: "abc",
  #             }
  #     page2 = %{
  #               id: "page:test-4",
  #               page_num: 2,
  #               text: "def",
  #             }

  #     TestRepo.insert_all(BookPage, [page1, page2])
  #     ids = [page1.id, page2.id]
  #     pages = [1, 2]

  #     hc_query = from bp in BookPage, where: bp.id in ["page:test-3", "page:test-4"] and bp.page_num in [1, 2]
  #     var_query = from bp in BookPage, where: bp.id in ^ids and bp.page_num in ^pages

  #     TestRepo.update_all(hc_query, set: [text: "Call me Ishmael..."])

  #     hc_result = TestRepo.all(hc_query)
  #                 |> Enum.map(fn(item) -> item.text end)

  #     assert hc_result == ["Call me Ishmael...", "Call me Ishmael..."]

  #     TestRepo.update_all(var_query, set: [text: "... or just Joe would be fine."])

  #     var_result = TestRepo.all(var_query)
  #                  |> Enum.map(fn(item) -> item.text end)

  #     assert var_result == ["... or just Joe would be fine.", "... or just Joe would be fine."]
  #   end
  # end

  # describe "Repo.delete/1" do
  #   test "delete a single record" do
  #     id = "person:delete"
  #     {:ok, _} = TestRepo.insert(%Person{
  #                  id: id,
  #                  first_name: "Delete",
  #                  age: 37,
  #                  email: "delete_all@test.com",
  #                })
  #                |> elem(1)
  #                |> TestRepo.delete()

  #     assert TestRepo.get(Person, id) == nil
  #   end
  # end

  # describe "Repo.delete_all/2" do
  #   test "delete multiple records" do
  #     TestRepo.insert(%Person{
  #                       id: "person:delete_all_1",
  #                       first_name: "Delete",
  #                       age: 26,
  #                       email: "delete_all@test.com",
  #                     })
  #     TestRepo.insert(%Person{
  #                       id: "person:delete_all_2",
  #                       first_name: "Delete",
  #                       age: 97,
  #                       email: "delete_all@test.com",
  #                     })

  #     assert nil != TestRepo.get(Person, "person:delete_all_1")
  #     assert nil != TestRepo.get(Person, "person:delete_all_2")

  #     result = TestRepo.delete_all((from p in Person, where: p.email == "delete_all@test.com"), query_info_key: "delete_all:test_key")
  #     assert {2, nil} == result

  #     assert nil == TestRepo.get(Person, "person:delete_all_1")
  #     assert nil == TestRepo.get(Person, "person:delete_all_2")
  #   end
  # end

  # describe "modifying records with composite primary keys" do
  #   test "update a record using a hash and range key" do
  #     assert {:ok, book_page} = TestRepo.insert(%BookPage{
  #       id: "gatsby",
  #       page_num: 1
  #     })

  #     {:ok, _} = BookPage.changeset(book_page, %{text: "Believe"})
  #     |> TestRepo.update()

  #     assert %BookPage{text: "Believe"}  = TestRepo.get_by(BookPage, [id: "gatsby", page_num: 1])

  #     {:ok, _} = TestRepo.delete(book_page)

  #     assert nil == TestRepo.get_by(BookPage, [id: "gatsby", page_num: 1])
  #   end

  #   test "update a record using the legacy :range_key option" do
  #     assert 1 == length(Planet.__schema__(:primary_key)), "the schema have a single key declared"

  #     assert {:ok, planet} = TestRepo.insert(%Planet{
  #       id: "neptune",
  #       name: "Neptune",
  #       mass: 123245
  #     })

  #     {:ok, updated_planet} =
  #       Ecto.Changeset.change(planet, mass: 0)
  #       |> TestRepo.update(range_key: {:name, planet.name})

  #     assert updated_planet == %Planet{
  #       __meta__: %Ecto.Schema.Metadata{
  #         state: :loaded,
  #         source: "test_planet",
  #         schema: Planet
  #       },
  #       id: "neptune",
  #       inserted_at: planet.inserted_at,
  #       mass: 0,
  #       name: "Neptune",
  #       updated_at: updated_planet.updated_at
  #     }

  #     {:ok, _} =
  #       TestRepo.delete(%Planet{id: planet.id}, range_key: {:name, planet.name})
  #   end
  # end


  defp make_list_of_people_for_batch_insert(total_records) do
    for i <- 0..total_records, i > 0 do
      id_string = :crypto.strong_rand_bytes(16) |> Base.url_encode64 |> binary_part(0, 16)
      id = "person:" <> id_string

      %{
        id: id,
        first_name: "Batch",
        last_name: "Insert",
        age: i,
        email: "batch_insert#{i}@test.com"
      }
    end
  end

  defp get_datetime_type(datetime) do
    {base_type, datetime_string} =
      case datetime do
        %NaiveDateTime{} ->
          {:naive_datetime, datetime |> NaiveDateTime.to_iso8601()}
        %DateTime{} ->
          {:utc_datetime, datetime |> DateTime.to_iso8601()}
      end

    if String.contains?(datetime_string, "."),
      do: :"#{base_type}_usec",
      else: base_type
  end
end
