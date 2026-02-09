defmodule Ecto.Adapters.DynamoDB.Test do
  @moduledoc """
  Unit tests for the adapter's main public API.
  """

  use ExUnit.Case, async: false

  import Ecto.Query
  import Mock

  alias Ecto.Adapters.DynamoDB
  alias Ecto.Adapters.DynamoDB.TestRepo
  alias Ecto.Adapters.DynamoDB.TestSchema.{Person, Address, BookPage, Planet, Fruit, Product}

  setup_all do
    TestHelper.setup_all()

    on_exit(fn ->
      TestHelper.on_exit()
    end)
  end

  test "get - no matching record" do
    result = TestRepo.get(Person, "person-faketestperson")
    assert result == nil
  end

  test "query - empty list param" do
    result = TestRepo.all(from(p in Person, where: p.id in []))
    assert result == []
  end

  describe "insert" do
    test "embedded records, source-mapped field, naive_datetime_usec and utc_datetime" do
      {:ok, insert_result} =
        TestRepo.insert(%Person{
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

      assert get_datetime_type((insert_result.addresses |> Enum.at(0)).updated_at) ==
               :utc_datetime

      assert insert_result.country == "England"

      assert insert_result.__meta__ == %Ecto.Schema.Metadata{
               state: :loaded,
               source: "test_person",
               schema: Person
             }

      get_result = TestRepo.get(Person, insert_result.id)
      assert get_result == insert_result
    end

    test "handles embedded records with parameterized fields" do
      {:ok, insert_result} =
        TestRepo.insert(%Person{
          id: "person:address:parameterized_test",
          first_name: "Ringo",
          last_name: "Starr",
          email: "ringo@test.com",
          age: 76,
          country: "England",
          type: :bar,
          addresses: [
            %Address{
              street_number: 245,
              street_name: "W 17th St",
              type: :foo
            },
            %Address{
              street_number: 1385,
              street_name: "Broadway"
            }
          ]
        })

      get_result = TestRepo.get(Person, insert_result.id)
      assert get_result == insert_result
    end

    test "without :insert_nil_fields option" do
      planet = %Planet{
        name: "Earth",
        mass: 1
      }

      {:ok, earth} = TestRepo.insert(planet)

      %{"Item" => earth_result} =
        ExAws.Dynamo.get_item("test_planet", %{id: earth.id, name: earth.name})
        |> request!()

      assert Map.has_key?(earth_result, "moons")
    end

    test ":insert_nil_fields option" do
      planet = %Planet{
        name: "Venus",
        mass: 2
      }

      {:ok, venus} = TestRepo.insert(planet, insert_nil_fields: false)

      %{"Item" => venus_result} =
        ExAws.Dynamo.get_item("test_planet", %{id: venus.id, name: venus.name})
        |> request!()

      refute Map.has_key?(venus_result, "moons")
    end
  end

  describe "empty MapSet handling" do
    test "Repo.insert without empty_mapset_to_nil" do
      assert_raise RuntimeError, "Cannot determine a proper data type for an empty MapSet", fn ->
        TestRepo.insert!(base_person_record())
      end
    end

    test "Repo.insert with empty_mapset_to_nil" do
      item = TestRepo.insert!(base_person_record(), empty_mapset_to_nil: true)

      %{"Item" => result} =
        "test_person"
        |> ExAws.Dynamo.get_item(%{id: item.id})
        |> request!()

      assert Map.has_key?(result, "tags_to_tags")
      assert result["tags_to_tags"] == %{"NULL" => true}
    end

    test "Repo.insert_all without empty_mapset_to_nil" do
      assert_raise RuntimeError, "Cannot determine a proper data type for an empty MapSet", fn ->
        TestRepo.insert_all(Person, [base_person_struct()])
      end
    end

    test "Repo.insert_all with empty_mapset_to_nil" do
      struct = base_person_struct()
      {1, nil} = TestRepo.insert_all(Person, [struct], empty_mapset_to_nil: true)

      %{"Item" => result} =
        "test_person"
        |> ExAws.Dynamo.get_item(%{id: struct.id})
        |> request!()

      assert Map.has_key?(result, "tags_to_tags")
      assert result["tags_to_tags"] == %{"NULL" => true}
    end

    test "Repo.get without nil_to_empty_mapset" do
      item = TestRepo.insert!(base_person_record(), empty_mapset_to_nil: true)

      result = TestRepo.get(Person, item.id)

      assert is_nil(result.tags_to_tags)
    end

    test "Repo.get with nil_to_empty_mapset" do
      item = TestRepo.insert!(base_person_record(), empty_mapset_to_nil: true)

      result = TestRepo.get(Person, item.id, nil_to_empty_mapset: true)

      assert MapSet.equal?(result.tags_to_tags, MapSet.new())
    end

    test "update with nil_to_empty_mapset" do
      item =
        %{base_person_record() | tags_to_tags: MapSet.new(["a", "b"])}
        |> TestRepo.insert!()
        |> Person.changeset(%{tags_to_tags: MapSet.new()})
        |> TestRepo.update!(empty_mapset_to_nil: true)

      result = TestRepo.get(Person, item.id, nil_to_empty_mapset: true)
      assert MapSet.equal?(result.tags_to_tags, MapSet.new())
    end

    test "update without nil_to_empty_mapset" do
      assert_raise RuntimeError, "Cannot determine a proper data type for an empty MapSet", fn ->
        %{base_person_record() | tags_to_tags: MapSet.new(["a", "b"])}
        |> TestRepo.insert!()
        |> Person.changeset(%{tags_to_tags: MapSet.new()})
        |> TestRepo.update!()
      end
    end

    test "Repo.insert with nil_to_empty_mapset true and insert_nil fields false" do
      item =
        TestRepo.insert!(base_person_record(),
          empty_mapset_to_nil: true,
          insert_nil_fields: false
        )

      %{"Item" => result} =
        "test_person"
        |> ExAws.Dynamo.get_item(%{id: item.id})
        |> request!()

      refute Map.has_key?(result, "tags_to_tags")
    end

    test "Repo.insert_all with nil_to_empty_mapset true and remove_nil_fields false" do
      struct = base_person_struct()

      {1, nil} =
        TestRepo.insert_all(Person, [struct], empty_mapset_to_nil: true, insert_nil_fields: false)

      %{"Item" => result} =
        "test_person"
        |> ExAws.Dynamo.get_item(%{id: struct.id})
        |> request!()

      refute Map.has_key?(result, "tags_to_tags")
    end

    test "update with nil_to_empty_mapset true and remove_nil_fields_on_update" do
      struct =
        %{base_person_record() | tags_to_tags: MapSet.new(["a", "b"])}
        |> TestRepo.insert!()
        |> Person.changeset(%{tags_to_tags: MapSet.new()})
        |> TestRepo.update!(empty_mapset_to_nil: true, remove_nil_fields_on_update: true)

      %{"Item" => result} =
        "test_person"
        |> ExAws.Dynamo.get_item(%{id: struct.id})
        |> request!()

      refute Map.has_key?(result, "tags_to_tags")
    end

    defp base_person_struct() do
      base_person_record()
      |> Map.from_struct()
      |> Map.put(:id, "test:id")
      |> Map.delete(:__meta__)
    end

    defp base_person_record() do
      %Person{
        first_name: "Update",
        last_name: "Test",
        age: 12,
        email: "update@test.com",
        tags_to_tags: MapSet.new()
      }
    end
  end

  describe "update" do
    test "update a single record" do
      TestRepo.insert(%Person{
        id: "person-update",
        first_name: "Update",
        last_name: "Test",
        age: 12,
        email: "update@test.com",
        # field nil_to_tags tests adding
        # the MapSet type where the value
        # was previously nil
        tags_to_tags: MapSet.new(["a", "b", "c"])
      })

      person = TestRepo.get(Person, "person-update")
      existing_tags = person.tags_to_tags
      new_tags = MapSet.put(existing_tags, "d")

      {:ok, result} =
        person
        |> Ecto.Changeset.change(
          first_name: "Updated",
          last_name: "Tested",
          tags_to_tags: new_tags,
          nil_to_tags: MapSet.new(["a", "b"])
        )
        |> TestRepo.update()

      assert result.first_name == "Updated"
      assert result.last_name == "Tested"
      assert MapSet.member?(result.tags_to_tags, "d")
      assert MapSet.member?(result.nil_to_tags, "a")
      assert MapSet.member?(result.nil_to_tags, "b")
    end

    test ":remove_nil_fields_on_update option" do
      {:ok, person} =
        TestRepo.insert(%Person{
          first_name: "Prince",
          last_name: "Rodgers",
          age: 40,
          email: "prince@test.com"
        })

      person
      |> Ecto.Changeset.change(country: "USA", last_name: nil)
      |> TestRepo.update(remove_nil_fields_on_update: true)

      %{"Item" => result} = ExAws.Dynamo.get_item("test_person", %{id: person.id}) |> request!()

      refute Map.has_key?(result, "last_name")
    end
  end

  test "insert_all" do
    # single
    total_records = 1
    people = make_list_of_people_for_batch_insert(total_records)
    result = TestRepo.insert_all(Person, people)

    assert result == {total_records, nil}

    # multiple
    # DynamoDB has a constraint on the call to BatchWriteItem, where attempts to insert more than
    # 25 records will be rejected. We allow the user to call insert_all() for more than 25 records
    # by breaking up the requests into blocks of 25.
    # https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_BatchWriteItem.html
    total_records = 55
    people = make_list_of_people_for_batch_insert(total_records)
    result = TestRepo.insert_all(Person, people)

    assert result == {total_records, nil}
  end

  describe "update_all and query" do
    test "update_all - hash primary key query with hard-coded params" do
      person1 = %{
        id: "person-george",
        first_name: "George",
        last_name: "Washington",
        age: 70,
        email: "george@washington.com"
      }

      person2 = %{
        id: "person-thomas",
        first_name: "Thomas",
        last_name: "Jefferson",
        age: 27,
        email: "thomas@jefferson.com"
      }

      TestRepo.insert_all(Person, [person1, person2])

      from(p in Person, where: p.id in ["person-george", "person-thomas"])
      |> TestRepo.update_all(set: [last_name: nil])

      result =
        from(p in Person, where: p.id in ["person-george", "person-thomas"], select: p.last_name)
        |> TestRepo.all()

      assert result == [nil, nil]
    end

    test "update_all - composite primary key query with pinned variable params" do
      page1 = %{
        id: "page:test-3",
        page_num: 1,
        text: "abc"
      }

      page2 = %{
        id: "page:test-4",
        page_num: 2,
        text: "def"
      }

      TestRepo.insert_all(BookPage, [page1, page2])

      ids = [page1.id, page2.id]
      pages = [1, 2]

      from(bp in BookPage, where: bp.id in ^ids and bp.page_num in ^pages)
      |> TestRepo.update_all(set: [text: "Call me Ishmael..."])

      result =
        from(bp in BookPage, where: bp.id in ^ids and bp.page_num in ^pages, select: bp.text)
        |> TestRepo.all()

      assert result == ["Call me Ishmael...", "Call me Ishmael..."]
    end
  end

  test "delete" do
    {:ok, person} =
      TestRepo.insert(%Person{
        id: "person:delete",
        first_name: "Delete",
        age: 37,
        email: "delete@test.com"
      })

    TestRepo.delete(person)

    assert TestRepo.get(Person, person.id) == nil
  end

  test "delete_all" do
    person_1 = %{
      id: "person:delete_all_1",
      first_name: "Delete",
      age: 26,
      email: "delete_all@test.com"
    }

    person_2 = %{
      id: "person:delete_all_2",
      first_name: "Delete",
      age: 97,
      email: "delete_all@test.com"
    }

    TestRepo.insert_all(Person, [person_1, person_2])

    result =
      from(p in Person, where: p.id in ^[person_1.id, person_2.id])
      |> TestRepo.delete_all()

    assert {2, nil} == result
  end

  describe "update, get_by" do
    test "update and get_by record using a hash and range key, utc_datetime_usec" do
      assert {:ok, book_page} =
               TestRepo.insert(%BookPage{
                 id: "gatsby",
                 page_num: 1
               })

      {:ok, _} =
        BookPage.changeset(book_page, %{text: "Believe"})
        |> TestRepo.update()

      result = TestRepo.get_by(BookPage, id: "gatsby", page_num: 1)

      assert %BookPage{text: "Believe"} = result
      assert get_datetime_type(result.inserted_at) == :utc_datetime_usec
    end

    test "update a record using the legacy :range_key option, naive_datetime" do
      assert 1 == length(Planet.__schema__(:primary_key)), "the schema have a single key declared"

      assert {:ok, planet} =
               TestRepo.insert(%Planet{
                 id: "neptune",
                 name: "Neptune",
                 mass: 123_245
               })

      assert get_datetime_type(planet.inserted_at) == :naive_datetime

      {:ok, updated_planet} =
        Ecto.Changeset.change(planet, mass: 0)
        |> TestRepo.update(range_key: {:name, planet.name})

      assert %Planet{
               __meta__: %Ecto.Schema.Metadata{
                 state: :loaded,
                 source: "test_planet",
                 schema: Planet
               },
               mass: 0
             } = updated_planet

      {:ok, _} = TestRepo.delete(%Planet{id: planet.id}, range_key: {:name, planet.name})
    end
  end

  describe "query" do
    test "query on composite primary key, hash and hash + range" do
      name = "houseofleaves"

      page_1 = %BookPage{
        id: name,
        page_num: 1,
        text: "abc"
      }

      page_2 = %BookPage{
        id: name,
        page_num: 2,
        text: "def"
      }

      duplicate_page = %BookPage{
        id: name,
        page_num: 1,
        text: "ghi"
      }

      {:ok, page_1} = BookPage.changeset(page_1) |> TestRepo.insert()
      {:ok, page_2} = BookPage.changeset(page_2) |> TestRepo.insert()

      assert BookPage.changeset(duplicate_page)
             |> TestRepo.insert()
             |> elem(0) == :error

      [hash_res_1, hash_res_2] =
        from(p in BookPage, where: p.id == ^name)
        |> TestRepo.all()
        |> Enum.sort_by(& &1.page_num)

      assert hash_res_1 == page_1
      assert hash_res_2 == page_2

      assert from(p in BookPage,
               where:
                 p.id == ^"houseofleaves" and
                   p.page_num == 1
             )
             |> TestRepo.all() == [page_1]

      assert from(p in BookPage,
               where:
                 p.id == ^page_2.id and
                   p.page_num == ^page_2.page_num
             )
             |> TestRepo.all() == [page_2]
    end

    test "multi-condition primary key/global secondary index" do
      {:ok, person} =
        TestRepo.insert(%Person{
          id: "person:jamesholden",
          first_name: "James",
          last_name: "Holden",
          age: 18,
          email: "jholden@expanse.com"
        })

      assert from(p in Person,
               where:
                 p.id == ^"person:jamesholden" and
                   p.email == ^"jholden@expanse.com",
               select: p.id
             )
             |> TestRepo.all()
             |> Enum.at(0) == person.id
    end

    test "'all... in...' query, hard-coded and a variable list of primary hash keys" do
      person1 = %{
        id: "person-moe",
        first_name: "Moe",
        last_name: "Howard",
        age: 75,
        email: "moe@stooges.com"
      }

      person2 = %{
        id: "person-larry",
        first_name: "Larry",
        last_name: "Fine",
        age: 72,
        email: "larry@stooges.com"
      }

      TestRepo.insert_all(Person, [person1, person2])

      ids = [person1.id, person2.id]
      sorted_ids = Enum.sort(ids)

      assert from(p in Person,
               where: p.id in ^ids,
               select: p.id
             )
             |> TestRepo.all()
             |> Enum.sort() == sorted_ids

      assert from(p in Person,
               where: p.id in ^["person-moe", "person-larry"],
               select: p.id
             )
             |> TestRepo.all()
             |> Enum.sort() == sorted_ids
    end

    test "'all... in...' query, hard-coded and a variable lists of composite primary keys" do
      page_1 = %{
        id: "page:test-1",
        page_num: 1,
        text: "abc"
      }

      page_2 = %{
        id: "page:test-2",
        page_num: 2,
        text: "def"
      }

      TestRepo.insert_all(BookPage, [page_1, page_2])

      ids = [page_1.id, page_2.id]
      pages = [1, 2]
      sorted_ids = Enum.sort(ids)

      assert from(bp in BookPage,
               where:
                 bp.id in ^ids and
                   bp.page_num in ^pages
             )
             |> TestRepo.all()
             |> Enum.map(& &1.id)
             |> Enum.sort() == sorted_ids

      assert from(bp in BookPage,
               where:
                 bp.id in ^["page:test-1", "page:test-2"] and
                   bp.page_num in [1, 2]
             )
             |> TestRepo.all()
             |> Enum.map(& &1.id)
             |> Enum.sort() == sorted_ids
    end

    test "'all... in...' query on a hash key global secondary index, hard-coded and variable list, range condition" do
      person_1 = %{
        id: "person-jerrytest",
        first_name: "Jerry",
        last_name: "Garcia",
        age: 55,
        email: "jerry@test.com"
      }

      person_2 = %{
        id: "person-bobtest",
        first_name: "Bob",
        last_name: "Weir",
        age: 70,
        email: "bob@test.com"
      }

      emails = [person_1.email, person_2.email]
      sorted_ids = Enum.sort([person_1.id, person_2.id])

      TestRepo.insert_all(Person, [person_1, person_2])

      assert from(p in Person,
               where: p.email in ^emails,
               select: p.id
             )
             |> TestRepo.all()
             |> Enum.sort() == sorted_ids

      assert from(p in Person,
               where: p.email in ^["jerry@test.com", "bob@test.com"],
               select: p.id
             )
             |> TestRepo.all()
             |> Enum.sort() == sorted_ids

      assert from(p in Person,
               where:
                 p.email in ^emails and
                   p.age > 69,
               select: p.id
             )
             |> TestRepo.all() == [person_2.id]

      assert from(p in Person,
               where:
                 p.email in ^["jerry@test.com", "bob@test.com"] and
                   p.age < 69,
               select: p.id
             )
             |> TestRepo.all() == [person_1.id]
    end

    test "'all... in...' query on a hash key global secondary index, hard-coded and variable list, range condition using concurrent tasks" do
      Application.put_env(:ecto_adapters_dynamodb, :concurrent_batch, true)
      Application.put_env(:ecto_adapters_dynamodb, :max_fetch_concurrency, 4)
      Application.put_env(:ecto_adapters_dynamodb, :min_concurrent_fetch_batch, 1)

      person_1 = %{
        id: "person-jerrytest",
        first_name: "Jerry",
        last_name: "Garcia",
        age: 55,
        email: "jerry@test.com"
      }

      person_2 = %{
        id: "person-bobtest",
        first_name: "Bob",
        last_name: "Weir",
        age: 70,
        email: "bob@test.com"
      }

      person_3 = %{
        id: "person-neiltest",
        first_name: "Neil",
        last_name: "Young",
        age: 71,
        email: "neil@test.com"
      }

      person_4 = %{
        id: "person-jamestest",
        first_name: "James",
        last_name: "Brown",
        age: 72,
        email: "james@test.com"
      }

      people = [person_1, person_2, person_3, person_4]

      emails = Enum.map(people, & &1.email)
      sorted_ids = Enum.sort(Enum.map(people, & &1.id))

      TestRepo.insert_all(Person, people)

      assert from(p in Person,
               where: p.email in ^emails,
               select: p.id
             )
             |> TestRepo.all()
             |> Enum.sort() == sorted_ids

      assert from(p in Person,
               where: p.email in ^emails,
               select: p.id
             )
             |> TestRepo.all()
             |> Enum.sort() == sorted_ids

      assert from(p in Person,
               where:
                 p.email in ^emails and
                   p.age > 71,
               select: p.id
             )
             |> TestRepo.all()
             |> Enum.sort() == [person_4.id]

      assert from(p in Person,
               where:
                 p.email in ^emails and
                   p.age < 69,
               select: p.id
             )
             |> TestRepo.all() == [person_1.id]

      Application.delete_env(:ecto_adapters_dynamodb, :concurrent_batch)
      Application.delete_env(:ecto_adapters_dynamodb, :max_fetch_concurrency)
      Application.delete_env(:ecto_adapters_dynamodb, :min_concurrent_fetch_batch)
    end

    test "'all... in...' query on a hash key global secondary index, hard-coded and variable list, range condition with concurrent tasks enabled but only using one" do
      Application.put_env(:ecto_adapters_dynamodb, :concurrent_batch, true)
      Application.put_env(:ecto_adapters_dynamodb, :max_fetch_concurrency, 1)

      person_1 = %{
        id: "person-jerrytest",
        first_name: "Jerry",
        last_name: "Garcia",
        age: 55,
        email: "jerry@test.com"
      }

      person_2 = %{
        id: "person-bobtest",
        first_name: "Bob",
        last_name: "Weir",
        age: 70,
        email: "bob@test.com"
      }

      people = [person_1, person_2]

      emails = Enum.map(people, & &1.email)
      sorted_ids = Enum.sort(Enum.map(people, & &1.id))

      TestRepo.insert_all(Person, people)

      assert from(p in Person,
               where: p.email in ^emails,
               select: p.id
             )
             |> TestRepo.all()
             |> Enum.sort() == sorted_ids

      Application.delete_env(:ecto_adapters_dynamodb, :concurrent_batch)
      Application.delete_env(:ecto_adapters_dynamodb, :max_fetch_concurrency)
    end

    test "query secondary index, :index option provided to resolve ambiguous index choice" do
      person1 = %{
        id: "person-methuselah-baby",
        first_name: "Methuselah",
        last_name: "Baby",
        age: 0,
        email: "newborn_baby@test.com"
      }

      person2 = %{
        id: "person-methuselah-jones",
        first_name: "Methuselah",
        last_name: "Jones",
        age: 969,
        email: "methuselah@test.com"
      }

      TestRepo.insert_all(Person, [person1, person2])

      # based on the query, it won't be clear to the adapter whether to choose the first_name_age
      # or age_first_name index - pass the :index option to make sure it queries correctly.
      query =
        from(p in Person,
          where:
            p.first_name == "Methuselah" and
              p.age in [0, 969]
        )

      assert_raise ArgumentError,
                   "Ecto.Adapters.DynamoDB.Query.get_matching_secondary_index/4 error: :index option does not match existing secondary index names. Did you mean age_first_name?",
                   fn ->
                     query
                     |> TestRepo.all(index: "age_first_nam")
                   end

      assert query
             |> TestRepo.all(index: "age_first_name")
             |> length() == 2
    end

    test "composite primary key, using a 'begins_with' fragment on the range key" do
      name_fragment = "J"

      planet_1 = %{
        id: "planet",
        name: "Jupiter",
        mass: 6_537_292_902,
        moons: MapSet.new(["Io", "Europa", "Ganymede"])
      }

      planet_2 = %{
        id: "planet",
        name: "Pluto",
        mass: 3465
      }

      TestRepo.insert_all(Planet, [planet_1, planet_2])

      assert from(p in Planet,
               where:
                 p.id == ^"planet" and
                   fragment("begins_with(?, ?)", p.name, ^name_fragment),
               select: p.moons
             )
             |> TestRepo.all() == [planet_1.moons]
    end

    test "global secondary index with a composite key, using a 'begins_with' fragment on the range key" do
      email_fragment = "m"

      person_1 = %{
        id: "person-michael-jordan",
        first_name: "Michael",
        last_name: "Jordan",
        age: 52,
        email: "mjordan@test.com"
      }

      person_2 = %{
        id: "person-michael-macdonald",
        first_name: "Michael",
        last_name: "MacDonald",
        age: 74,
        email: "singin_dude@test.com"
      }

      TestRepo.insert_all(Person, [person_1, person_2])

      assert from(p in Person,
               where:
                 p.first_name == ^"Michael" and
                   fragment("begins_with(?, ?)", p.email, ^email_fragment),
               select: p.id
             )
             |> TestRepo.all() == [person_1.id]
    end

    test "'all... in...' query on a composite global secondary index" do
      person1 = %{
        id: "person:frank",
        first_name: "Frank",
        last_name: "Sinatra",
        age: 45,
        email: "frank_sinatra@test.com"
      }

      person2 = %{
        id: "person:dean",
        first_name: "Dean",
        last_name: "Martin",
        age: 70,
        email: "dean_martin@test.com"
      }

      TestRepo.insert_all(Person, [person1, person2])

      first_names = [person1.first_name, person2.first_name]

      assert from(p in Person,
               where:
                 p.first_name in ^first_names and
                   p.age < 50,
               select: p.id
             )
             |> TestRepo.all() == ["person:frank"]
    end

    test "partial primary key and hash-only secondary indexes, 'in' and '==' operations" do
      planet_1 = %{
        id: "planet-mercury",
        name: "Mercury",
        mass: 153
      }

      planet_2 = %{
        id: "planet-saturn",
        name: "Saturn",
        mass: 409_282_891,
        moons: MapSet.new(["Titan", "Enceladus", "Iapetus"])
      }

      TestRepo.insert_all(Planet, [planet_1, planet_2])

      assert from(p in Planet,
               where: p.name in ^[planet_1.name, planet_2.name]
             )
             |> TestRepo.all() ==
               from(p in Planet,
                 where: p.id in ^[planet_1.id, planet_2.id]
               )
               |> TestRepo.all()

      assert from(p in Planet,
               where: p.name == ^planet_1.name
             )
             |> TestRepo.all() ==
               from(p in Planet,
                 where: p.id == ^planet_1.id
               )
               |> TestRepo.all()
    end

    test "get multiple records on a partial secondary index composite key (hash only)" do
      person1 = %{
        id: "person:wayne_shorter",
        first_name: "Wayne",
        last_name: "Shorter",
        age: 75,
        email: "wayne_shorter@test.com"
      }

      person2 = %{
        id: "person:wayne_campbell",
        first_name: "Wayne",
        last_name: "Campbell",
        age: 36,
        email: "wayne_campbell@test.com"
      }

      TestRepo.insert_all(Person, [person1, person2])

      sorted_ids = Enum.sort([person1.id, person2.id])

      assert from(p in Person,
               where: p.first_name == "Wayne",
               select: p.id
             )
             |> TestRepo.all()
             |> Enum.sort() == sorted_ids
    end

    test "scan query option" do
      fruit_1 = %{name: "apple"}
      fruit_2 = %{name: "orange"}

      TestRepo.insert_all(Fruit, [fruit_1, fruit_2])

      assert_raise ArgumentError,
                   "Ecto.Adapters.DynamoDB.Query.maybe_scan/3 error: :scan option or configuration have not been specified, and could not confirm the table, \"test_fruit\", as listed for scan or caching in the application's configuration. Please see README file for details.",
                   fn ->
                     TestRepo.all(Fruit)
                   end

      assert TestRepo.all(Fruit, scan: true)
             |> length() == 2
    end
  end

  # DynamoDB has a constraint on the call to BatchGetItem, where attempts to retrieve more than 100 records will be rejected.
  # We allow the user to call all() for more than 100 records by breaking up the requests into blocks of 100.
  # https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_BatchGetItem.html
  # Similarly, calls to BatchWriteItem (which affects insert_all and delete_all operations)
  # are restricted to 25 records per call - so those should be similarly batched.
  test "exceed BatchGetItem and BatchWriteItem limits" do
    total_records = 110
    people_to_insert = make_list_of_people_for_batch_insert(total_records)
    person_ids = for person <- people_to_insert, do: person.id

    TestRepo.insert_all(Person, people_to_insert)

    assert from(p in Person,
             where: p.id in ^person_ids
           )
           |> TestRepo.all()
           |> length() == total_records

    assert from(p in Person, where: p.id in ^person_ids)
           |> TestRepo.update_all(set: [last_name: "Foobar"]) == {total_records, []}

    assert from(p in Person, where: p.id in ^person_ids)
           |> TestRepo.delete_all() == {total_records, nil}

    assert from(p in Person,
             where: p.id in ^person_ids
           )
           |> TestRepo.all()
           |> length() == 0
  end

  test "tuple argument for select" do
    id = "person:tuple_argument_for_select"
    email = "hj@test.com"

    TestRepo.insert(%Person{
      id: id,
      first_name: "heebie",
      last_name: "jeebie",
      email: email,
      age: 12553
    })

    assert from(p in Person,
             where: p.first_name == "heebie",
             select: {p.email}
           )
           |> TestRepo.all() == [{email}]

    assert from(p in Person,
             where: p.first_name == "heebie",
             select: {p.id, p.email}
           )
           |> TestRepo.all() == [{id, email}]
  end

  describe "TransactionConflictException successful retry handling" do
    setup do
      Process.put(:ex_aws_request_calls, 0)

      fruit = %Fruit{name: "fruit"}
      {:ok, fruit} = TestRepo.insert(fruit)

      {:ok, fruit: fruit}
    end

    test_with_mock "insert retry success", ExAws, [:passthrough], conflict_mock() do
      fruit = %Fruit{name: "Orange"}
      {:ok, fruit} = TestRepo.insert(fruit)

      result =
        ExAws.Dynamo.get_item("test_fruit", %{id: fruit.id})
        |> request!()

      assert result["Item"]["name"]["S"] == fruit.name

      assert_called_exactly(ExAws.request(:_, :_), 2)
    end

    test_with_mock "update retry success",
                   %{fruit: fruit},
                   ExAws,
                   [:passthrough],
                   conflict_mock() do
      fruit
      |> Fruit.changeset(%{name: "banana"})
      |> TestRepo.update!()

      assert %Fruit{name: "banana"} = TestRepo.get_by(Fruit, id: fruit.id)

      assert_called_exactly(ExAws.request(:_, :_), 2)
    end

    test_with_mock "delete retry success",
                   %{fruit: fruit},
                   ExAws,
                   [:passthrough],
                   conflict_mock() do
      fruit
      |> TestRepo.delete()

      assert nil == TestRepo.get_by(Fruit, id: fruit.id)

      assert_called_exactly(ExAws.request(:_, :_), 2)
    end

    defp conflict_mock do
      [
        request: fn request, config ->
          Process.put(:ex_aws_request_calls, (Process.get(:ex_aws_request_calls) || 0) + 1)

          case Process.get(:ex_aws_request_calls) do
            x when x < 2 ->
              {:error, {"TransactionConflictException", "Transaction is ongoing for the item"}}

            _ ->
              passthrough([request, config])
          end
        end
      ]
    end
  end

  describe "TransactionConflictException failed retry handling" do
    @raises ~r/maximum transaction conflict retries/

    setup do
      Process.put(:ex_aws_request_calls, 0)

      fruit = %Fruit{name: "fruit"}
      {:ok, fruit} = TestRepo.insert(fruit)

      {:ok, fruit: fruit}
    end

    test_with_mock "insert retry success", ExAws, [:passthrough], conflict_fail_mock() do
      fruit = %Fruit{name: "Orange"}

      assert_raise RuntimeError, @raises, fn ->
        TestRepo.insert(fruit)
      end

      assert_called_exactly(ExAws.request(:_, :_), DynamoDB.max_transaction_conflict_retries())
    end

    test_with_mock "update retry success",
                   %{fruit: fruit},
                   ExAws,
                   [:passthrough],
                   conflict_fail_mock() do
      assert_raise RuntimeError, @raises, fn ->
        fruit
        |> Fruit.changeset(%{name: "banana"})
        |> TestRepo.update!()
      end

      assert_called_exactly(ExAws.request(:_, :_), DynamoDB.max_transaction_conflict_retries())
    end

    test_with_mock "delete retry success",
                   %{fruit: fruit},
                   ExAws,
                   [:passthrough],
                   conflict_fail_mock() do
      assert_raise RuntimeError, @raises, fn ->
        fruit
        |> TestRepo.delete()
      end

      assert_called_exactly(ExAws.request(:_, :_), DynamoDB.max_transaction_conflict_retries())
    end

    defp conflict_fail_mock do
      [
        request: fn _request, _config ->
          {:error, {"TransactionConflictException", "Transaction is ongoing for the item"}}
        end
      ]
    end
  end

  describe "decimal type handling" do
    test "insert and retrieve decimal fields" do
      {:ok, product} =
        TestRepo.insert(%Product{
          id: "product:decimal-test",
          name: "Test Product",
          price: Decimal.new("104.50"),
          discount: Decimal.new("10.25"),
          tax_rate: Decimal.new("0.08")
        })

      assert product.price == Decimal.new("104.50")
      assert product.discount == Decimal.new("10.25")
      assert product.tax_rate == Decimal.new("0.08")

      retrieved = TestRepo.get(Product, "product:decimal-test")
      assert retrieved.price == Decimal.new("104.50")
      assert retrieved.discount == Decimal.new("10.25")
      assert retrieved.tax_rate == Decimal.new("0.08")
    end

    test "insert with string decimal values" do
      {:ok, product} =
        TestRepo.insert(%Product{
          id: "product:string-decimal-test",
          name: "String Test Product",
          price: "95.00",
          discount: "5.50",
          tax_rate: "0.12"
        })

      retrieved = TestRepo.get(Product, "product:string-decimal-test")
      assert retrieved.price == Decimal.new("95.00")
      assert retrieved.discount == Decimal.new("5.50")
      assert retrieved.tax_rate == Decimal.new("0.12")
    end

    test "insert with nil decimal values" do
      {:ok, product} =
        TestRepo.insert(%Product{
          id: "product:nil-decimal-test",
          name: "Nil Test Product",
          price: Decimal.new("50.00"),
          discount: nil,
          tax_rate: nil
        })

      retrieved = TestRepo.get(Product, "product:nil-decimal-test")
      assert retrieved.price == Decimal.new("50.00")
      assert retrieved.discount == nil
      assert retrieved.tax_rate == nil
    end

    test "query with decimal fields" do
      {:ok, _} =
        TestRepo.insert(%Product{
          id: "product:query-test-1",
          name: "Query Test 1",
          price: Decimal.new("100.00")
        })

      {:ok, _} =
        TestRepo.insert(%Product{
          id: "product:query-test-2",
          name: "Query Test 2",
          price: Decimal.new("200.00")
        })

      products =
        from(p in Product,
          where: p.id in ["product:query-test-1", "product:query-test-2"],
          select: [p.id, p.price]
        )
        |> TestRepo.all()
        |> Enum.sort()

      assert length(products) == 2
      assert Enum.at(products, 0) == ["product:query-test-1", Decimal.new("100.00")]
      assert Enum.at(products, 1) == ["product:query-test-2", Decimal.new("200.00")]
    end
  end

  # Private

  defp make_list_of_people_for_batch_insert(total_records) do
    for i <- 0..total_records, i > 0 do
      id_string = :crypto.strong_rand_bytes(16) |> Base.url_encode64() |> binary_part(0, 16)
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

  defp request!(operation), do: ExAws.request!(operation, DynamoDB.ex_aws_config(TestRepo))
end
