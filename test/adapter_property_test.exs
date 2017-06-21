defmodule AdapterPropertyTest do
  use ExUnit.Case
  use EQC.ExUnit  

  alias Ecto.Adapters.DynamoDB.TestRepo
  alias Ecto.Adapters.DynamoDB.TestSchema.Person

  setup_all do
    TestHelper.setup_all("property_test_person")
  end

  def nonempty_str() do
    such_that s <- utf8() do
      # Ecto.Changeset.validate_required checks for all-whitespace
      # strings in addition to empty ones, hence the trimming:
      String.trim_leading(s) != ""
    end
  end

  def circle_list() do
    non_empty(list(nonempty_str()))
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
    forall person <- person_generator() do
      when_fail(IO.puts "Failed for person #{inspect person}") do
        TestRepo.insert! Person.changeset(person)
        result = TestRepo.get(Person, person.id)
        ensure person == result
      end
    end
  end
end
