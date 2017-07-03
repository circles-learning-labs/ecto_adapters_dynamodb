defmodule AdapterPropertyTest do
  use ExUnit.Case
  use EQC.ExUnit  

  alias Ecto.Adapters.DynamoDB.TestRepo
  alias Ecto.Adapters.DynamoDB.TestSchema.Person

  setup_all do
    TestHelper.setup_all("property_test_person")
  end

  property "test insert/get returns the same value" do
    forall person <- TestGenerators.person_generator() do
      when_fail(IO.puts "Failed for person #{inspect person}") do
        TestRepo.insert!(Person.changeset(person), overwrite: true)
        result = TestRepo.get(Person, person.id)
        ensure person == result
      end
    end
  end
end
