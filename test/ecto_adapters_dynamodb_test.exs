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

  describe "Repo.insert/1" do
    test "insert a single record" do
      {:ok, result} = TestRepo.insert(%Person{
                                 id: "person-hello",
                                 circles: nil,
                                 first_name: "Hello",
                                 last_name: "World",
                                 age: 34,
                                 email: "hello@world.com",
                                 password: "password",
                               })

      assert result == %Ecto.Adapters.DynamoDB.TestSchema.Person{
                         age: 34,
                         circles: nil,
                         email: "hello@world.com",
                         first_name: "Hello",
                         id: "person-hello",
                         last_name: "World",
                         password: "password",
                         __meta__: %Ecto.Schema.Metadata{
                                     context: nil,
                                     source: {nil, @test_table},
                                     state: :loaded,
                                   },
                       }
    end

    test "insert embedded records" do
      address_list = [
                       %Address{
                         street_number: 245,
                         street_name: "W 17th St"
                       },
                       %Address{
                         street_number: 1385,
                         street_name: "Broadway"
                       }
                     ]
      {:ok, result} = TestRepo.insert(%Person{
                                        id: "person:address_test",
                                        email: "addr@test.com",
                                        addresses: address_list
                                      })

      assert length(result.addresses) == 2
    end
  end

  describe "Repo.get/2" do
    test "Repo.get/2 - no matching record" do
      result = TestRepo.get(Person, "person-faketestperson")
      assert result == nil
    end

    test "insert a record and retrieve it by its primary key" do
      TestRepo.insert(%Person{
        id: "person-john",
        circles: nil,
        first_name: "John",
        last_name: "Lennon",
        age: 40,
        email: "john@beatles.com",
        password: "password",
        role: "musician"
      })
      result = TestRepo.get(Person, "person-john")

      assert result.first_name == "John"
      assert result.last_name == "Lennon"
      assert Ecto.get_meta(result, :state) == :loaded
    end

    test "insert a record and get with a hash/range pkey" do
      name = "houseofleaves"
      page1 = %BookPage{
                id: name,
                page_num: 1,
                text: "abc",
              }
      page2 = %BookPage{
                id: name,
                page_num: 2,
                text: "def",
              }
      cs1 = BookPage.changeset(page1)
      cs2 = BookPage.changeset(page2)
      duplicate_page_cs = BookPage.changeset(%BookPage{
                                               id: name,
                                               page_num: 1,
                                               text: "ghi",
                                             })

      {:ok, page1} = TestRepo.insert(cs1)
      {:ok, page2} = TestRepo.insert(cs2)
      {:error, _} = TestRepo.insert(duplicate_page_cs)

      query = from p in BookPage, where: p.id == ^name
      results = query |> TestRepo.all |> Enum.sort_by(&(&1.page_num))
      [res1, res2] = results

      assert res1 == page1
      assert res2 == page2

      query1 = from p in BookPage, where: p.id == ^name and p.page_num == 1
      query2 = from p in BookPage, where: p.id == ^name and p.page_num == 2

      assert [page1] == TestRepo.all(query1)
      assert [page2] == TestRepo.all(query2)
    end    
  end

  describe "Repo.insert_all/2" do
    test "batch-insert multiple records" do
      total_records = 5
      result = handle_batch_insert_person(total_records)

      assert result == {total_records, nil}
    end

    test "batch-insert a single record" do
      total_records = 1
      result = handle_batch_insert_person(total_records)

      assert result == {total_records, nil}
    end

    # DynamoDB has a constraint on the call to BatchWriteItem, where attempts to insert more than
    # 25 records will be rejected. We allow the user to call insert_all() for more than 25 records
    # by breaking up the requests into blocks of 25.
    # https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_BatchWriteItem.html
    test "batch-insert multiple records, exceeding BatchWriteItem limit by 30 records" do
      total_records = 55
      result = handle_batch_insert_person(total_records)

      assert result == {total_records, nil}
    end
  end

  describe "Repo.all" do
    test "batch-get multiple records when querying for an empty list" do
      result = TestRepo.all(from p in Person, where: p.id in [])
      assert result == []
    end

    test "batch-get multiple records with an 'all... in...' query when querying for a hard-coded and an interpolated list" do
      person1 = %{
                  id: "person-moe",
                  circles: nil,
                  first_name: "Moe",
                  last_name: "Howard",
                  age: 75,
                  email: "moe@stooges.com",
                  password: "password",
                }
      person2 = %{
                  id: "person-larry",
                  circles: nil,
                  first_name: "Larry",
                  last_name: "Fine",
                  age: 72,
                  email: "larry@stooges.com",
                  password: "password",
                }
      person3 = %{
                  id: "person-curly",
                  circles: nil,
                  first_name: "Curly",
                  last_name: "Howard",
                  age: 74,
                  email: "curly@stooges.com",
                  password: "password",
                }

      TestRepo.insert_all(Person, [person1, person2, person3])

      ids = [person1.id, person2.id, person3.id]
      sorted_ids = Enum.sort(ids)
      int_result = TestRepo.all(from p in Person, where: p.id in ^ids)
                   |> Enum.map(&(&1.id))
                   |> Enum.sort()
      hc_result = TestRepo.all(from p in Person, where: p.id in ["person-moe", "person-larry", "person-curly"])
                  |> Enum.map(&(&1.id))
                  |> Enum.sort()

      assert int_result == sorted_ids
      assert hc_result == sorted_ids
    end

    test "batch-get multiple records with an 'all... in...' query on a hash key global secondary index when querying for a hard-coded and interpolated list" do
      person1 = %{
        id: "person-jerrytest",
        circles: nil,
        first_name: "Jerry",
        last_name: "Garcia",
        age: 55,
        email: "jerry@test.com",
        password: "password",
      } 
      person2 = %{
        id: "person-bobtest",
        circles: nil,
        first_name: "Bob",
        last_name: "Weir",
        age: 70,
        email: "bob@test.com",
        password: "password"
      }

      TestRepo.insert_all(Person, [person1, person2])

      emails = [person1.email, person2.email]
      sorted_ids = Enum.sort([person1.id, person2.id])
      int_result = TestRepo.all(from p in Person, where: p.email in ^emails)
                   |> Enum.map(&(&1.id))
                   |> Enum.sort()
      hc_result = TestRepo.all(from p in Person, where: p.email in ["jerry@test.com", "bob@test.com"])
                  |> Enum.map(&(&1.id))
                  |> Enum.sort()

      assert int_result == sorted_ids
      assert hc_result == sorted_ids
    end

    # DynamoDB has a constraint on the call to BatchGetItem, where attempts to retrieve more than
    # 100 records will be rejected. We allow the user to call all() for more than 100 records
    # by breaking up the requests into blocks of 100.
    # https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_BatchGetItem.html
    test "batch-get multiple records, exceeding BatchGetItem limit by 10 records" do
      total_records = 110
      people_to_insert = make_list_of_people_for_batch_insert(total_records) # create a list of people records
      person_ids = for person <- people_to_insert, do: person.id # hang on to the ids separately

      handle_batch_insert_person(people_to_insert) # insert the records

      result = TestRepo.all(from p in Person, where: p.id in ^person_ids)
               |> Enum.map(&(&1.id))

      assert length(result) == total_records
    end

    test "batch-insert and query all on a single-condition global secondary index" do
      person1 = %{
                  id: "person-tomtest",
                  circles: nil,
                  first_name: "Tom",
                  last_name: "Jones",
                  age: 70,
                  email: "jones@test.com",
                  password: "password",
                }
      person2 = %{
                  id: "person-caseytest",
                  circles: nil,
                  first_name: "Casey",
                  last_name: "Jones",
                  age: 114,
                  email: "jones@test.com",
                  password: "password",
                }
      person3 = %{
                  id: "person-jamestest",
                  circles: nil,
                  first_name: "James",
                  last_name: "Jones",
                  age: 71,
                  email: "jones@test.com",
                  password: "password",
                }

      TestRepo.insert_all(Person, [person1, person2, person3])
      result = TestRepo.all(from p in Person, where: p.email == "jones@test.com")

      assert length(result) == 3
    end

    test "query all on a multi-condition primary key/global secondary index" do
      TestRepo.insert(%Person{
                        id: "person:jamesholden",
                        first_name: "James",
                        last_name: "Holden",
                        email: "jholden@expanse.com",
                      })
      result = TestRepo.all(from p in Person, where: p.id == "person:jamesholden" and p.email == "jholden@expanse.com")

      assert Enum.at(result, 0).first_name == "James"
      assert Enum.at(result, 0).last_name == "Holden"
    end
  end

  describe "Repo.update/1" do
    test "update two fields on a record" do
      TestRepo.insert(%Person{
                        id: "person-update",
                        circles: nil,
                        first_name: "Update",
                        last_name: "Test",
                        age: 12,
                        email: "update@test.com",
                        password: "password",
                      })
      {:ok, result} = TestRepo.get(Person, "person-update")
                      |> Ecto.Changeset.change([first_name: "Updated", last_name: "Tested"])
                      |> TestRepo.update()

      assert result.first_name == "Updated"
      assert result.last_name == "Tested"
    end
  end

  describe "Repo.delete/1" do
    test "delete a single record" do
      person_id = "person:delete"
      {:ok, _} = TestRepo.insert(%Person{
                   id: person_id,
                   email: "delete_all@test.com",
                 })
                 |> elem(1)
                 |> TestRepo.delete()

      assert TestRepo.get(Person, person_id) == nil
    end
  end

  describe "Repo.delete_all/2" do
    test "delete multiple records" do
      TestRepo.insert(%Person{
                        id: "person:delete_all_1",
                        email: "delete_all@test.com",
                      })
      TestRepo.insert(%Person{
                        id: "person:delete_all_2",
                        email: "delete_all@test.com",
                      })

      assert nil != TestRepo.get(Person, "person:delete_all_1")
      assert nil != TestRepo.get(Person, "person:delete_all_2")

      result = TestRepo.delete_all((from p in Person, where: p.email == "delete_all@test.com"), query_info_key: "delete_all:test_key")
      assert {2, nil} == result

      assert nil == TestRepo.get(Person, "person:delete_all_1")
      assert nil == TestRepo.get(Person, "person:delete_all_2")
    end
  end


  # Batch insert a list of records into the Person model.
  defp handle_batch_insert_person(people_to_insert) when is_list people_to_insert do
    TestRepo.insert_all(Person, people_to_insert)
  end
  defp handle_batch_insert_person(total_records) when is_integer total_records do
    make_list_of_people_for_batch_insert(total_records)
    |> handle_batch_insert_person()
  end

  defp make_list_of_people_for_batch_insert(total_records) do
    for i <- 0..total_records, i > 0 do
      id_string = :crypto.strong_rand_bytes(16) |> Base.url_encode64 |> binary_part(0, 16)
      id = "person:" <> id_string

      %{
        id: id,
        circles: nil,
        first_name: "Batch",
        last_name: "Insert",
        age: i,
        email: "batch_insert#{i}@test.com",
        password: "password",
      }
    end   
  end

end
