defmodule AdapterPropertyTest do
  use ExUnit.Case
  use EQC.ExUnit  

  import Ecto.Query

  alias ExAws.Dynamo
  alias Ecto.Adapters.DynamoDB.TestRepo
  alias Ecto.Adapters.DynamoDB.TestSchema.Person

  @test_table "property_test_person"  

  setup_all do
    IO.puts "starting test repo"
    TestRepo.start_link()

    IO.puts "deleting any leftover test tables that may exist"
    Dynamo.delete_table(@test_table) |> ExAws.request

    IO.puts "creating test table"
    # Only need to define types for indexed fields:
    key_definitions = %{id: :string, email: :string}
    indexes = [%{
               index_name: "email",
               key_schema: [%{
                            attribute_name: "email",
                            key_type: "HASH",
               }],
               provisioned_throughput: %{
                 read_capacity_units: 100,
                 write_capacity_units: 100,
               },
               projection: %{projection_type: "ALL"}
    }]
    Dynamo.create_table(@test_table, [id: :hash], key_definitions, 100, 100, indexes, []) |> ExAws.request!

    :ok
  end

  def string() do
    utf8()
  end

  def nonempty_str() do
    such_that s <- string() do
      s != ""
    end
  end

  def circle_list do
    such_that l <- list(nonempty_str()) do
      l != []
    end
  end

  def person_generator() do
    let {id, first, last, age, email, pass, circles} <-
        {nonempty_str(), nonempty_str(), nonempty_str(), int(),
          nonempty_str(), nonempty_str(), circle_list()} do
      %Person{
        id: id,
        first_name: first,
        last_name: last,
        age: age,
        email: email,
        password: pass,
        circles: circles
      }
    end
  end

  property "test insert/get returns the same value" do
    forall person <- person_generator do
      when_fail(IO.puts "Failed for person #{inspect person}") do
        TestRepo.insert Person.changeset(person)
        result = TestRepo.get(Person, person.id)
        ensure person == result
      end
    end
  end
end
